/**
 * @description
 * Unit tests for Loan_Charge__c object.
 *
 * @author Mark Brennand
 */
@IsTest
public with sharing class LoanChargeTests {
    private final static Set<String> TYPES = new Set<String> { Helper.INTEREST_CHARGE, 'Legal Fee', Helper.ADMIN_FEE };

    @TestSetup
    private static void setup() {
        TestHelper.setupUser();
    }

    @IsTest
    private static void testLoanChargeCreation() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            List<Loan_Charge__c> charges = new List<Loan_Charge__c>();
            for (Loan__c loan : loans) {
                for (String type : TYPES) {
                    charges.add(new Loan_Charge__c(
                            Loan__c = loan.Id,
                            Charge_Type__c = type,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 100.0
                    ));
                }
            }

            insert charges;

            for (String type : TYPES) {
                Assert.areEqual(1, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id AND Charge_Type__c = :type]);
                Assert.areEqual(1, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id AND Charge_Type__c = :type]);
            }
        }
    }

    @IsTest
    private static void testChargeBeforeLoanStartNotAllowed() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            Datetime whence = Helper.NOW.addDays(-1);
            List<Loan_Charge__c> charges = new List<Loan_Charge__c>();

            for (Loan__c loan : loans) {
                for (String type : TYPES) {
                    charges.add(new Loan_Charge__c(
                            Loan__c = loan.Id,
                            Charge_Type__c = type,
                            Charge_Date__c = whence.date(),
                            Amount__c = 100.0
                    ));

                    whence = Helper.NOW;
                }
            }

            Test.startTest();

            try {
                insert charges;
            } catch (DMLException de) {
                Assert.isTrue(de.getMessage().contains(Label.Invalid_Interest_Charge_Date));
            }

            charges.clear();
            for (Loan__c loan : loans) {
                for (String type : TYPES) {
                    charges.add(new Loan_Charge__c(
                            Loan__c = loan.Id,
                            Charge_Type__c = type,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 100.0
                    ));
                }
            }

            insert charges;

            for (Loan_Charge__c charge : charges) {
                charge.Amount__c = 10000;
            }

            charges[3].Charge_Date__c = Helper.NOW.addDays(-1).date();
            try {
                update charges;
            } catch (DMLException de) {
                Assert.isTrue(de.getMessage().contains(Label.Invalid_Interest_Charge_Date));
            }

            Test.stopTest();
        }
    }

    @IsTest
    private static void testReleaseChargeCannotBeDeleted() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            Test.startTest();

            try {
                Loan_Charge__c charge = [SELECT Id FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id];
                delete charge;
            } catch (DMLException de) {
                Assert.isTrue(de.getMessage().contains(Label.Release_Charge_Cannot_Be_Deleted));
            }

            try {
                Loan_Charge__c charge = [SELECT Id FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id];
                delete charge;
            } catch (DMLException de) {
                Assert.isTrue(de.getMessage().contains(Label.Release_Charge_Cannot_Be_Deleted));
            }

            try {
                delete [SELECT Id FROM Loan_Charge__c];
            } catch (DMLException de) {
                Assert.isTrue(de.getMessage().contains(Label.Release_Charge_Cannot_Be_Deleted));
            }

            Test.stopTest();
        }
    }

    @IsTest
    private static void testOnlyOneReleaseChargeAllowedPerLoan() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            Test.startTest();

            try {
                insert new List<Loan_Charge__c>{
                        new Loan_Charge__c(
                                Loan__c = loans[0].Id,
                                Charge_Type__c = Helper.INTEREST_CHARGE,
                                Charge_Date__c = Helper.NOW.date(),
                                Amount__c = 100.0
                        ),
                        new Loan_Charge__c(
                                Loan__c = loans[1].Id,
                                Charge_Type__c = Helper.RELEASE_CHARGE,
                                Charge_Date__c = Helper.NOW.date(),
                                Amount__c = 101.0
                        ),
                        new Loan_Charge__c(
                                Loan__c = loans[1].Id,
                                Charge_Type__c = Helper.INTEREST_CHARGE,
                                Charge_Date__c = Helper.NOW.date(),
                                Amount__c = 100.0
                        )
                };
            } catch (DMLException de) {
                System.debug(de.getMessage());
                Assert.isTrue(de.getMessage().contains(Label.Only_One_Release_Charge_Allowed));
            }

            Test.stopTest();
        }
    }

    @IsTest
    private static void testReleaseChargeIsMoved() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            Test.startTest();

            insert new List<Loan_Charge__c> {
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Amount__c = 100.0,
                            Charge_Date__c = Helper.NOW.date(),
                            Charge_Type__c = Helper.INTEREST_CHARGE
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[1].Id,
                            Amount__c = 100.0,
                            Charge_Date__c = Helper.NOW.date(),
                            Charge_Type__c = Helper.INTEREST_CHARGE
                    )
            };

            Assert.areEqual(loans[0].Date_Loan_Issued__c.addMonths(2), [SELECT Charge_Date__c FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id AND Charge_Type__c = :Helper.RELEASE_CHARGE].Charge_Date__c);
            Assert.areEqual(loans[1].Date_Loan_Issued__c.addMonths(3), [SELECT Charge_Date__c FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id AND Charge_Type__c = :Helper.RELEASE_CHARGE].Charge_Date__c);

            insert new List<Loan_Charge__c> {
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Amount__c = 100.0,
                            Charge_Date__c = Helper.NOW.addDays(107).date(),
                            Charge_Type__c = Helper.INTEREST_CHARGE
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[1].Id,
                            Amount__c = 100.0,
                            Charge_Date__c = Helper.NOW.addDays(347).date(),
                            Charge_Type__c = Helper.INTEREST_CHARGE
                    )
            };

            Assert.areEqual(Helper.NOW.addDays(107).addMonths(1).date(), [SELECT Charge_Date__c FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id AND Charge_Type__c = :Helper.RELEASE_CHARGE].Charge_Date__c);
            Assert.areEqual(Helper.NOW.addDays(347).addMonths(1).date(), [SELECT Charge_Date__c FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id AND Charge_Type__c = :Helper.RELEASE_CHARGE].Charge_Date__c);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testChargeTypeCannotBeChanged() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            List<Loan_Charge__c> charges = new List<Loan_Charge__c>();
            for (Loan__c loan : loans) {
                for (String type : TYPES) {
                    charges.add(new Loan_Charge__c(
                            Loan__c = loan.Id,
                            Charge_Type__c = type,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 100.0
                    ));
                }
            }

            Test.startTest();

            insert charges;

            for (Loan_Charge__c charge : charges) {
                charge.Amount__c = 100000;
            }

            charges[2].Charge_Type__c = charges[2].Charge_Type__c == 'Legal Fee' ? Helper.INTEREST_CHARGE : 'Legal Fee';

            try {
                upsert charges;
            } catch(DmlException de) {
                Assert.isTrue(de.getMessage().contains(Label.Charge_Type_Cannot_Be_Changed));
            }

            Test.stopTest();
        }
    }
}