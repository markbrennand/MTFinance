/**
 * @description
 * Class providing utility methods for use by Apex classes providing Loan processing.
 *
 * @author Mark Brennand
 */
public with sharing class Helper {
    public static String RELEASE_CHARGE = 'Release Charge';
    public static String INTEREST_CHARGE = 'Interest Charge';
    public static String ADMIN_FEE = 'Admin Fee';
    public static Decimal RELEASE_CHARGE_FEE = 500.0;
    public static Decimal CHANGE_TERM_FEE = 300.0;

    @TestVisible
    public static Datetime NOW {
        public get {
            return Datetime.now();
        }
        private set;
    }
}