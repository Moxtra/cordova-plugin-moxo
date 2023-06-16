package com.moxtra.mepplugin;

import com.moxtra.mepsdk.ErrorCodes;

public class ErrorCodeUtil {
    public static final int ERROR_BASE = 0;
    public static final int MEPUnknownError = ERROR_BASE;
    public static final int MEPDomainsError = ERROR_BASE + 1;
    public static final int MEPInvalidAccountError = ERROR_BASE + 2;
    public static final int MEPNotLinkedError = ERROR_BASE + 3;
    public static final int MEPNetworkError = ERROR_BASE + 4;
    public static final int MEPObjectNotFoundError = ERROR_BASE + 5;
    public static final int MEPAuthorizedError = ERROR_BASE + 6;
    public static final int MEPAccountDisabled = ERROR_BASE + 7;
    public static final int MEPAccountLocked = ERROR_BASE + 8;
    public static final int MEPMeetEndedError = ERROR_BASE + 9;
    public static final int MEPPermissionError = ERROR_BASE + 10;

    public static String getErrorMsg(int errorCode) {
        switch (errorCode) {
            case MEPUnknownError:
                return "something went wrong";
            case MEPDomainsError:
                return "invalid domain";
            case MEPInvalidAccountError:
                return "invalid access token";
            case MEPNotLinkedError:
                return "sdk not initialized";
            case MEPNetworkError:
                return "no network";
            case MEPObjectNotFoundError:
                return "object not found";
            case MEPAuthorizedError:
                return "account not authorized";
            case MEPAccountDisabled:
                return "account disabled";
            case MEPAccountLocked:
                return "account locked";
            case MEPMeetEndedError:
                return "meet ended";
            case MEPPermissionError:
                return "no permission";
        }

        return "something went wrong";
    }

    public static int convert2CordovaErrorCode(int errorCode) {
        switch (errorCode) {
            case ErrorCodes.MEPUnknownError:
                return MEPUnknownError;
            case ErrorCodes.MEPDomainsError:
                return MEPDomainsError;
            case ErrorCodes.MEPInvalidAccountError:
                return MEPInvalidAccountError;
            case ErrorCodes.MEPNotLinkedError:
                return MEPNotLinkedError;
            case ErrorCodes.MEPNetworkError:
                return MEPNetworkError;
            case ErrorCodes.MEPObjectNotFoundError:
                return MEPObjectNotFoundError;
            case ErrorCodes.MEPAuthorizedError:
                return MEPAuthorizedError;
            case ErrorCodes.MEPAccountDisabledError:
                return MEPAccountDisabled;
            case ErrorCodes.MEPAccountLockedError:
                return MEPAccountLocked;
            case ErrorCodes.MEPMeetEndedError:
                return MEPMeetEndedError;
            case ErrorCodes.MEPPermissionError:
                return MEPPermissionError;
        }

        return MEPUnknownError;
    }

}
