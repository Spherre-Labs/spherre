pub mod Errors {
    pub const ERR_DEPLOYER_ZERO: felt252 = 'Deployer should not be zero';
    pub const ERR_OWNER_ZERO: felt252 = 'Owner should not be zero';
    pub const ERR_INVALID_MEMBER_THRESHOLD: felt252 = 'Members must meet threshold';
    pub const NON_ZERO_MEMBER_LENGTH: felt252 = 'Members count must be > 0';
    pub const INVALID_CALLER: felt252 = 'Can only renounce role for self';
    pub const MISSING_ROLE: felt252 = 'Caller is missing role';
    pub const ThresholdError: felt252 = 'Threshold is too high, lower it';
    pub const NON_ZERO_THRESHOLD: felt252 = 'Threshold must be > 0';
    pub const ERR_NOT_OWNER: felt252 = 'Caller is not the owner';
    pub const ERR_NOT_MEMBER: felt252 = 'Caller is not a member';
    pub const ERR_NOT_PROPOSER: felt252 = 'Caller is not a proposer';
    pub const ERR_NOT_VOTER: felt252 = 'Caller is not a voter';
    pub const ERR_NOT_EXECUTOR: felt252 = 'Caller is not an executor';
    pub const ERR_INVALID_TRANSACTION: felt252 = 'Transaction is out of range';
    pub const ERR_TRANSACTION_NOT_VOTABLE: felt252 = 'Transaction is not votable';
    pub const ERR_TRANSACTION_NOT_EXECUTABLE: felt252 = 'Transaction is not executable';
    pub const ERR_TRANSACTION_ALREADY_EXECUTED: felt252 = 'Transaction already executed';
    pub const ERR_CALLER_CANNOT_VOTE: felt252 = 'Caller cannot vote again';
    pub const ERR_NOT_DEPLOYER: felt252 = 'Caller is not deployer';
    pub const ERR_CALL_WHILE_PAUSED: felt252 = 'Contract is paused';
    pub const ERR_NON_ZERO_ADDRESS_NFT_CONTRACT: felt252 = 'NFT contract address is zero';
    pub const ERR_NO_PROPOSER_PERMISSION: felt252 = 'Caller is not a proposer';
    pub const ERR_INVALID_NFT_TRANSACTION: felt252 = 'Invalid NFT transaction';
    pub const ERR_NFT_NOT_OWNED: felt252 = 'Caller does not own the NFT';
    pub const ERR_NON_ZERO_ACCOUNT: felt252 = 'Account should not be zero';
    pub const ERR_INSUFFICIENT_FEE: felt252 = 'Insufficient fee balance';
    pub const ERR_INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient fee allowance';
    pub const ERR_CALLER_NOT_DEPLOYED_ACCOUNT: felt252 = 'Caller is not an account';
    pub const ERR_INVALID_TRANSACTION_TYPE: felt252 = 'Invalid transaction type';

    pub const ERR_THRESHOLD_UNCHANGED: felt252 = 'Threshold is unchanged';
    pub const ERR_THRESHOLD_EXCEEDS_VOTERS: felt252 = 'Threshold exceeds total voters';
    pub const ERR_INVALID_THRESHOLD_TRANSACTION: felt252 = 'Invalid threshold transaction';

    pub const ERR_NOT_A_STAFF: felt252 = 'Caller is not a staff';
    pub const ERR_NOT_A_SUPERADMIN: felt252 = 'Caller is not a superadmin';
    pub const ERR_TRANSACTION_INDEX_OUT_OF_RANGE: felt252 = 'Transaction Index Out Of Range';
    pub const ERR_TRANSACTION_LIMIT_OUT_OF_RANGE: felt252 = 'Transaction Limit Out Of Range';

    // Constants for token transaction
    pub const ERR_NON_ZERO_ADDRESS_TOKEN: felt252 = 'Token address is zero';
    pub const ERR_NON_ZERO_ADDRESS_RECIPIENT: felt252 = 'Recipient address is zero';
    pub const ERR_INSUFFICIENT_TOKEN_AMOUNT: felt252 = 'Insufficient token amount';
    pub const ERR_RECIPIENT_CANNOT_BE_ACCOUNT: felt252 = 'Recipient cannot be account';
    pub const ERR_INVALID_AMOUNT: felt252 = 'Amount is invalid';
    pub const ERR_INVALID_TOKEN_TRANSACTION: felt252 = 'Invalid Token Transaction Type';
    pub const ERR_ERC20_TRANSFER_FAILED: felt252 = 'ERC20 transfer failed';
    pub const ERR_INVALID_PERCENTAGE: felt252 = 'Invalid deploy fee percentage';

    // Token locking specific errors
    pub const ERR_ZERO_LOCK_AMOUNT: felt252 = 'Lock amount cannot be zero';
    pub const ERR_ZERO_LOCK_DURATION: felt252 = 'Lock duration cannot be zero';
    pub const ERR_ZERO_LOCK_ID: felt252 = 'Lock ID cannot be zero';
    pub const ERR_LOCK_NOT_FOUND: felt252 = 'Lock plan not found';
    pub const ERR_LOCK_ALREADY_UNLOCKED: felt252 = 'Lock already unlocked';

    pub const MEMBER_NOT_FOUND: felt252 = 'Member does not exist';
    pub const INVALID_MEMBER_REMOVE_TRANSACTION: felt252 = 'Not member remove proposal';
    pub const INSUFFICIENT_MEMBERS_AFTER_REMOVAL: felt252 = 'Would violate minimum threshold';
    pub const TRANSACTION_NOT_FOUND: felt252 = 'Transaction not found';

    pub const ERR_ACCOUNT_CLASSHASH_UNKNOWN: felt252 = 'Account Classhash not set';
    // New errors for class hash functionality
    pub const ERR_INVALID_CLASS_HASH: felt252 = 'Invalid class hash';
    pub const ERR_SAME_CLASS_HASH: felt252 = 'Class hash unchanged';

    // errors for member add transaction
    pub const ERR_INVALID_MEMBER_ADD_TRANSACTION: felt252 = 'Invalid member add transaction';
    pub const ERR_INVALID_PERMISSION_MASK: felt252 = 'Permission mask is invalid';
    pub const ERR_ALREADY_A_MEMBER: felt252 = 'Address is already a member';
    pub const ERR_NON_ZERO_MEMBER_ADDRESS: felt252 = 'Member address is zero';
    pub const ERR_ZERO_MEMBER_ADDRESS: felt252 = 'Member address is zero';
    pub const ERR_SAME_PERMISSIONS: felt252 = 'Permission unchanged';

    // errors for member remove transaction
    pub const ERR_CANNOT_REMOVE_LAST_VOTER: felt252 = 'Cannot remove last voter';
    pub const ERR_CANNOT_REMOVE_LAST_PROPOSER: felt252 = 'Cannot remove last proposer';
    pub const ERR_CANNOT_REMOVE_LAST_EXECUTOR: felt252 = 'Cannot remove last executor';
    pub const ERR_CANNOT_REMOVE_MEMBER_WITH_THRESHOLD: felt252 = 'lower threshold';

    // errors for member permission transaction
    pub const ERR_INVALID_MEMBER_PERMISSION_TRANSACTION: felt252 = 'Invalid edit permission txn';

    pub const ERR_LOCK_DURATION_NOT_ELAPSED: felt252 = 'Lock duration not elapsed';

    // errors for smart token lock transaction
    pub const ERR_INVALID_SMART_TOKEN_LOCK_TRANSACTION: felt252 = 'Invalid Token Lock Transaction';
    pub const ERR_INVALID_TOKEN_LOCK_DURATION: felt252 = 'Invalid Token Lock Duration';

    // Smart Will Errors
    pub const ERR_WILL_ADDRESS_IS_MEMBER: felt252 = 'Will address cannot be member';
    pub const ERR_WILL_ADDRESS_ALREADY_ASSIGNED: felt252 = 'Will address already assigned';
    pub const ERR_WILL_DURATION_NOT_ELAPSED: felt252 = 'Will duration not elapsed';
    pub const ERR_INVALID_WILL_ADDRESS: felt252 = 'Invalid will address';
    pub const ERR_WILL_DURATION_HAS_ELAPSED: felt252 = 'Will duration has elapsed';
    pub const AUTHORITY_DELEGATED_TO_WILL: felt252 = 'Authority delegated to will';
    pub const ERR_RESET_WINDOW_NOT_ACTIVE: felt252 = 'Reset window is not active';
    pub const ERR_WILL_WALLET_NOT_SET: felt252 = 'Will wallet not set';

    // errors for whitelist management
    pub const ERR_ACCOUNT_NOT_DEPLOYED: felt252 = 'Account is not deployed';
    pub const ERR_ACCOUNT_ALREADY_WHITELISTED: felt252 = 'Account already whitelisted';
    pub const ERR_USER_ALREADY_WHITELISTED: felt252 = 'User already whitelisted';
    pub const ERR_USER_ADDRESS_IS_ZERO: felt252 = 'User address is zero';
    pub const ERR_ACCOUNT_NOT_WHITELISTED: felt252 = 'Account not whitelisted';
    pub const ERR_USER_NOT_WHITELISTED: felt252 = 'User not whitelisted';
}
