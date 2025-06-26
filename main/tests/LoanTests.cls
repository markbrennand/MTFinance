/**
 * @description
 * Unit tests for Loan__c object.
 *
 * @author Mark Brennand
 */
@IsTest
public with sharing class LoanTests {

    @TestSetup
    private static void setup() {
        TestHelper.setupUser();
    }

    @IsTest
    private static void testReleaseChargesCreated() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            Account account = new Account(Name = 'Bananaman');
            insert account;

            Test.startTest();

            List<Loan__c> loans = TestHelper.createLoans();
            Test.stopTest();

            List<Loan_Charge__c> charges = TestHelper.getCharges(loans[0]);
            Assert.areEqual(1, charges.size());
            Assert.areEqual(Helper.RELEASE_CHARGE, charges[0].Charge_Type__c);
            Assert.areEqual(500.0, charges[0].Amount__c);
            Assert.areEqual(Helper.NOW.addMonths(2).date(), charges[0].Charge_Date__c);

            charges = TestHelper.getCharges(loans[1]);
            Assert.areEqual(1, charges.size());
            Assert.areEqual(Helper.RELEASE_CHARGE, charges[0].Charge_Type__c);
            Assert.areEqual(500.0, charges[0].Amount__c);
            Assert.areEqual(Helper.NOW.addMonths(3).date(), charges[0].Charge_Date__c);
        }
    }

    @IsTest
    private static void testDeletion() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            Account account = new Account(Name = 'Bananaman');
            insert account;

            List<Loan__c> loans = TestHelper.createLoans();

            Test.startTest();

            Assert.areEqual(1, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id]);
            Assert.areEqual(1, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id]);

            delete loans[0];
            Assert.areEqual(0, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id]);
            Assert.areEqual(1, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id]);

            delete loans[1];
            Assert.areEqual(0, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id]);
            Assert.areEqual(0, [SELECT COUNT() FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id]);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTermChange() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();
            Decimal startTotalLoan1 = [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[0].Id].Total_Charges_on_the_Loan__c;
            Decimal startTotalLoan2 = [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[1].Id].Total_Charges_on_the_Loan__c;

            Test.startTest();

            update new List<Loan__c> {
                    new Loan__c(Id = loans[0].Id, Term__c = 12),
                    new Loan__c(Id = loans[1].Id, Term__c = 16)
            };

            Test.stopTest();

            Assert.isFalse([SELECT Id FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id AND Charge_Date__c = :Helper.NOW.date() AND Charge_Type__c = :Helper.ADMIN_FEE AND Amount__c = 300.0 ].isEmpty());
            Assert.isFalse([SELECT Id FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id AND Charge_Date__c = :Helper.NOW.date() AND Charge_Type__c = :Helper.ADMIN_FEE AND Amount__c = 300.0 ].isEmpty());
            Assert.isFalse([SELECT Id FROM Loan_Charge__c WHERE Loan__c = :loans[0].Id AND Charge_Date__c = :loans[0].Date_Loan_Issued__c.addMonths(12) AND Charge_Type__c = :Helper.RELEASE_CHARGE AND Amount__c = 500.0 ].isEmpty());
            Assert.isFalse([SELECT Id FROM Loan_Charge__c WHERE Loan__c = :loans[1].Id AND Charge_Date__c = :loans[1].Date_Loan_Issued__c.addMonths(16) AND Charge_Type__c = :Helper.RELEASE_CHARGE AND Amount__c = 500.0 ].isEmpty());
            Assert.areEqual(startTotalLoan1 + 300.0, [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[0].Id].Total_Charges_on_the_Loan__c);
            Assert.areEqual(startTotalLoan2 + 300.0, [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[1].Id].Total_Charges_on_the_Loan__c);
        }
    }

    @IsTest
    private static void testTotalsComputedCorrectly() {
        System.runAs(TestHelper.getUser()) {
            Helper.NOW = Datetime.newInstance(2025, 1, 1);

            List<Loan__c> loans = TestHelper.createLoans();

            Test.startTest();

            insert new List<Loan_Charge__c>{
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Charge_Type__c = Helper.INTEREST_CHARGE,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 1.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Charge_Type__c = 'Legal Fee',
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 4.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Charge_Type__c = Helper.ADMIN_FEE,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 16.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Charge_Type__c = Helper.INTEREST_CHARGE,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 64.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[1].Id,
                            Charge_Type__c = Helper.INTEREST_CHARGE,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 2.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[1].Id,
                            Charge_Type__c = Helper.ADMIN_FEE,
                            Charge_Date__c = Helper.NOW.date(),
                            Amount__c = 8.0
                    )
            };

            Assert.areEqual(585.0, [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[0].Id].Total_Charges_on_the_Loan__c);
            Assert.areEqual(687.35, [SELECT Balance_of_the_Loan__c FROM Loan__c WHERE Id = :loans[0].Id].Balance_of_the_Loan__c);

            Assert.areEqual(510.0, [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[1].Id].Total_Charges_on_the_Loan__c);
            Assert.areEqual(2499.92, [SELECT Balance_of_the_Loan__c FROM Loan__c WHERE Id = :loans[1].Id].Balance_of_the_Loan__c);

            insert new List<Loan_Charge__c>{
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Charge_Type__c = Helper.INTEREST_CHARGE,
                            Charge_Date__c = Helper.NOW.addMonths(3).date(),
                            Amount__c = 256.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[0].Id,
                            Charge_Type__c = Helper.ADMIN_FEE,
                            Charge_Date__c = Helper.NOW.addMonths(6).date(),
                            Amount__c = 1024.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[1].Id,
                            Charge_Type__c = 'Legal Fee',
                            Charge_Date__c = Helper.NOW.addMonths(12).date(),
                            Amount__c = 32.0
                    ),
                    new Loan_Charge__c(
                            Loan__c = loans[1].Id,
                            Charge_Type__c = Helper.INTEREST_CHARGE,
                            Charge_Date__c = Helper.NOW.addMonths(24).date(),
                            Amount__c = 128.0
                    )
            };

            Assert.areEqual(1865.0, [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[0].Id].Total_Charges_on_the_Loan__c);
            Assert.areEqual(1967.35, [SELECT Balance_of_the_Loan__c FROM Loan__c WHERE Id = :loans[0].Id].Balance_of_the_Loan__c);

            Assert.areEqual(670.0, [SELECT Total_Charges_on_the_Loan__c FROM Loan__c WHERE Id = :loans[1].Id].Total_Charges_on_the_Loan__c);
            Assert.areEqual(2659.92, [SELECT Balance_of_the_Loan__c FROM Loan__c WHERE Id = :loans[1].Id].Balance_of_the_Loan__c);

            Test.stopTest();
        }
    }
}