/**
 * @description
 * Class implementing logic required for Loan trigger.
 *
 * Bulkification is used wherever possible.
 *
 * @author Mark Brennand
 */
public with sharing class LoanTriggerHandler {

    /**
     * @description
     * Processes the Loan records passed to the trigger.
     *
     * @param type Type of trigger action being performed.
     * @param loans The records that are being persisted.
     * @param oldLoans The previous value of the records being persisted if an update is being performed.
     */
    public static void processRecords(
            final TriggerType type,
            final List<Loan__c> loans,
            final Map<Id, Loan__c> oldLoans
    ) {
        switch on type {
            when CREATED {
                addReleaseCharge(loans);
            }
            when UPDATED {
                adjustReleaseCharge(loans, oldLoans);
            }
        }
    }

    private static void addReleaseCharge(final List<Loan__c> loans) {
        final List<Loan_Charge__c> releaseCharges = new List<Loan_Charge__c>();
        for (Loan__c loan : loans) {
            releaseCharges.add(
                    new Loan_Charge__c(
                            Loan__c = loan.Id,
                            Charge_Type__c = Helper.RELEASE_CHARGE,
                            Amount__c = Helper.RELEASE_CHARGE_FEE,
                            Charge_Date__c = loan.Date_Loan_Issued__c.addMonths((Integer) loan.Term__c)
                    )
            );
        }

        Database.insert(releaseCharges, AccessLevel.USER_MODE);
    }

    private static void adjustReleaseCharge(final List<Loan__c> loans, Map<Id, Loan__c> oldLoans) {
        final Set<Id> changedTermIds = new Set<Id>();
        final Map<Id, Date> endDates = new Map<Id, Date>();

        for (Loan__c loan : loans) {
            if (loan.Term__c != oldLoans.get(loan.Id)?.Term__c) {
                changedTermIds.add(loan.Id);
                endDates.put(loan.Id, loan.Date_Loan_Issued__c.addMonths((Integer) loan.Term__c));
            }
        }

        if (changedTermIds.isEmpty()) {
            return;
        }

        final List<Loan_Charge__c> releaseCharges = [
                SELECT Id, Loan__c, Charge_Date__c, Charge_Type__c
                FROM Loan_Charge__c
                WHERE Loan__c IN :changedTermIds AND Charge_Type__c = :Helper.RELEASE_CHARGE
        ];

        final Map<Id, Loan_Charge__c> releaseChargeLookup = new Map<Id, Loan_Charge__c>();
        for (Loan_Charge__c releaseCharge : releaseCharges) {
            releaseChargeLookup.put(releaseCharge.Loan__c, releaseCharge);
        }

        for (Id changedTermId : changedTermIds) {
            releaseChargeLookup.get(changedTermId).Charge_Date__c = endDates.get(changedTermId);
        }

        // This is something odd about SF. Setting the AccessLevel to USER_MODE causes an inaccessible field exception
        // despite a user with the Loan Manager permission set having full access to the Loan_Charge__c object.
        //
        // I think it's ok to use SYSTEM_MODE here as we wouldn't be reaching this point in the code if the user
        // didn't have write access to the Loan_Charge__c object.
        Database.update(releaseCharges, AccessLevel.SYSTEM_MODE);

        final List<Loan_Charge__c> adminCharges = new List<Loan_Charge__c>();
        for (Id changedTermId : changedTermIds) {
            adminCharges.add(
                    new Loan_Charge__c(
                            Loan__c = changedTermId,
                            Charge_Date__c = Helper.NOW.date(),
                            Charge_Type__c = Helper.ADMIN_FEE,
                            Amount__c = Helper.CHANGE_TERM_FEE
                    )
            );
        }

        Database.insert(adminCharges, AccessLevel.USER_MODE);
    }
}