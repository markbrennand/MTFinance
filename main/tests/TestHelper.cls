/**
 * @description
 * Utility methods for unit tests.
 *
 * @author Mark Brennand
 */
@IsTest
public with sharing class TestHelper {

    @TestVisible
    private static List<Loan_Charge__c> getCharges(Loan__c loan) {
        return [
                SELECT Id, Charge_Date__c, Charge_Type__c, Amount__c
                FROM Loan_Charge__c
                WHERE Loan__c = :loan.Id
        ];
    }

    @TestVisible
    private static List<Loan__c> createLoans() {
        Account account = new Account(Name = 'Bananaman');
        insert account;

        List<Loan__c> loans = new List<Loan__c> {
                newLoan(account, 2, 102.35),
                newLoan(account, 3, 1989.92)
        };

        insert loans;
        return loans;
    }

    private static Loan__c newLoan(Account account, Integer term, Decimal amount) {
        return new Loan__c(
                Account__c = account.Id,
                Gross_Loan_Amount__c = amount,
                Address__c = 'Their house',
                Term__c = (Decimal) term,
                Date_Loan_Issued__c = Helper.NOW.date()
        );
    }

    public static void setupUser() {
        final Id profileId = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1].Id;

        User user = new User(
                Alias = 'user',
                ProfileId = profileId,
                Username = 'test.user@mtfinance.test.com',
                Email = 'test.user@mtfinance.test.com',
                EmailEncodingKey = 'ISO-8859-1',
                TimeZoneSidKey = 'Europe/London',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                FirstName = 'Test',
                LastName = 'User'
        );

        insert user;

        Id managerPermSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Loan_Manager' LIMIT 1].Id;
        delete [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :user.Id AND PermissionSetId = :managerPermSetId];

        PermissionSetAssignment managerAssignment = new PermissionSetAssignment(
                AssigneeId = user.Id,
                PermissionSetId = managerPermSetId
        );

        insert managerAssignment;
    }

    public static User getUser() {
        return [SELECT Id FROM User WHERE Username = 'test.user@mtfinance.test.com' LIMIT 1];
    }
}