/**
 * @description
 * @author Mark Brennand
 */
public with sharing class LoanChargeTriggerHandler {

    /**
     * @description
     * Processes the Loan Charge records passed to the trigger.
     *
     * @param triggerType Type of trigger action being performed.
     * @param loanCharges The records that are being persisted.
     * @param oldLoanCharges The previous value of the records being persisted if an update is being performed.
     */
    public static void processRecords(
            final TriggerType triggerType,
            final List<Loan_Charge__c> loanCharges,
            final Map<Id, Loan_Charge__c> oldLoanCharges
    ) {
        final Set<Id> loanIds = new Set<Id>();
        for (Loan_Charge__c loanCharge : loanCharges) {
            loanIds.add(loanCharge.Loan__c);
        }

        final Map<Id, Loan__c> loans = new Map<Id, Loan__c>(getLoans(loanIds));
        final Map<Id, Loan_Charge__c> releaseCharges = new Map<Id, Loan_Charge__c>();

        for (Loan_Charge__c loanCharge : getLoanCharges(loanIds, Helper.RELEASE_CHARGE)) {
            if (!releaseCharges.containsKey(loanCharge.Loan__c)) {
                releaseCharges.put(loanCharge.Loan__c, loanCharge);
            } else {
                // We have more than one Release Charge for the same Loan. So, set the Loan Charge to null in
                // the Map to indicate that any Release Charge records for this Loan are in error.
                releaseCharges.put(loanCharge.Loan__c, null);
            }
        }

        if (validate(triggerType, loanCharges, oldLoanCharges, loans, releaseCharges)) {
            processReleaseCharge(loanCharges, releaseCharges);
        }
    }

    private static Boolean validate(
            final TriggerType type,
            final List<Loan_Charge__c> loanCharges,
            final Map<Id, Loan_Charge__c> oldLoanCharges,
            final Map<Id, Loan__c> loans,
            final Map<Id, Loan_Charge__c> releaseCharges
    ) {
        Boolean valid = true;

        switch on type {
            when CREATED {
                for (Loan_Charge__c loanCharge : loanCharges) {
                    valid &= validateDate(loanCharge, loans.get(loanCharge.Loan__c));

                    if ((loanCharge.Charge_Type__c == Helper.RELEASE_CHARGE)
                            && (releaseCharges.containsKey(loanCharge.Loan__c)
                            && loanCharge.Id != releaseCharges.get(loanCharge.Loan__c)?.Id))
                    {
                        loanCharge.Charge_Type__c.addError(Label.Only_One_Release_Charge_Allowed);
                        valid = false;
                    }
                }
            }

            when UPDATED {
                for (Loan_Charge__c loanCharge : loanCharges) {
                    valid &= validateDate(loanCharge, loans.get(loanCharge.Loan__c));

                    final Loan_Charge__c oldLoanCharge = oldLoanCharges.get(loanCharge.Id);
                    if (oldLoanCharge.Charge_Type__c != loanCharge.Charge_Type__c) {
                        loanCharge.Charge_Type__c.addError(Label.Charge_Type_Cannot_Be_Changed);
                        valid = false;
                    }
                }
            }

            when DELETED {
                for (Loan_Charge__c loanCharge : loanCharges) {
                    if (loanCharge.Charge_Type__c == Helper.RELEASE_CHARGE) {
                        loanCharge.addError(Label.Release_Charge_Cannot_Be_Deleted);
                        valid = false;
                    }
                }
            }
        }

        return valid;
    }

    private static void processReleaseCharge(
            final List<Loan_Charge__c> loanCharges,
            final Map<Id, Loan_Charge__c> releaseCharges
    ) {
        final Map<Id, Date> latestDates = new Map<Id, Date>();
        for (Loan_Charge__c loanCharge : loanCharges) {
            if (loanCharge.Charge_Type__c != Helper.RELEASE_CHARGE) {
                if (latestDates.containsKey(loanCharge.Loan__c)) {
                    if (loanCharge.Charge_Date__c > latestDates.get(loanCharge.Loan__c)) {
                        latestDates.put(loanCharge.Loan__c, loanCharge.Charge_Date__c);
                    }

                } else {
                    latestDates.put(loanCharge.Loan__c, loanCharge.Charge_Date__c);
                }
            }
        }

        final List<Loan_Charge__c> releaseChargesToUpdate = new List<Loan_Charge__c>();
        for (Id loanId : latestDates.keySet()) {
            final Loan_Charge__c releaseCharge = releaseCharges.get(loanId);
            final Date latestDate = latestDates.get(loanId);

            if (latestDate >= releaseCharge.Charge_Date__c) {
                // The records have come from SF, so are immutable. Hence, clone the record to persist.
                Loan_Charge__c cloned = releaseCharge.clone(true);
                cloned.Charge_Date__c = latestDate.addMonths(1);
                releaseChargesToUpdate.add(cloned);
            }
        }

        Database.upsert(releaseChargesToUpdate, AccessLevel.USER_MODE);
    }

    private static Boolean validateDate(final Loan_Charge__c loanCharge, final Loan__c loan) {
        if (loanCharge.Charge_Type__c == Helper.INTEREST_CHARGE && loanCharge.Charge_Date__c < loan.Date_Loan_Issued__c) {
            loanCharge.Charge_Date__c.addError(Label.Invalid_Interest_Charge_Date);
            return false;
        }

        return true;
    }

    private static List<Loan_Charge__c> getLoanCharges(final Set<Id> loanIds, final String chargeType) {
        return [
                SELECT Id, Loan__c, Amount__c, Charge_Type__c, Charge_Date__c
                FROM Loan_Charge__c
                WHERE Loan__c IN :loanIds
                AND Charge_Type__c = :chargeType
                WITH USER_MODE
        ];
    }

    private static List<Loan__c> getLoans(final Set<Id> loanIds) {
        return [
                SELECT Id, Date_Loan_Issued__c, Term__c
                FROM Loan__c
                WHERE Id IN :loanIds
        ];
    }
}