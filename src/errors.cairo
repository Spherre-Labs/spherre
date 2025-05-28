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
    pub const ERR_CALLER_CANNOT_VOTE: felt252 = 'Caller cannot vote again';
    pub const ERR_NOT_DEPLOYER: felt252 = 'Caller is not deployer';
    pub const ERR_CALL_WHILE_PAUSED: felt252 = 'Contract is paused';
    pub const ERR_NON_ZERO_ADDRESS_NFT_CONTRACT: felt252 = 'NFT contract address is zero';
    pub const ERR_NO_PROPOSER_PERMISSION: felt252 = 'Caller is not a proposer';
    pub const ERR_INVALID_NFT_TRANSACTION: felt252 = 'Invalid NFT transaction';
    pub const ERR_INVALID_TOKEN_ID: felt252 = 'Token ID is invalid';
    pub const ERR_THRESHOLD_UNCHANGED: felt252 = 'Threshold is unchanged';
    pub const ERR_THRESHOLD_EXCEEDS_VOTERS: felt252 = 'Threshold exceeds total voters';
    pub const ERR_INVALID_THRESHOLD_TRANSACTION: felt252 = 'Invalid threshold transaction';

    pub const ERR_NOT_A_STAFF: felt252 = 'Caller is not a staff';
    pub const ERR_NOT_A_SUPERADMIN: felt252 = 'Caller is not a superadmin';

    // Constants for token transaction
    pub const ERR_NON_ZERO_ADDRESS_TOKEN: felt252 = 'Token address is zero';
    pub const ERR_NON_ZERO_ADDRESS_RECIPIENT: felt252 = 'Recipient address is zero';
    pub const ERR_INSUFFICIENT_TOKEN_AMOUNT: felt252 = 'Insufficient token amount';
    pub const ERR_RECIPIENT_CANNOT_BE_ACCOUNT: felt252 = 'Recipient cannot be account';
    pub const ERR_INVALID_AMOUNT: felt252 = 'Amount is invalid';
    pub const ERR_INVALID_TOKEN_TRANSACTION: felt252 = 'Invalid Token Transaction';

    pub const MEMBER_NOT_FOUND: felt252 = 'Member does not exist';
    pub const INVALID_MEMBER_REMOVE_TRANSACTION: felt252 = 'Not member remove proposal';
    pub const INSUFFICIENT_MEMBERS_AFTER_REMOVAL: felt252 = 'Would violate minimum threshold';
    pub const TRANSACTION_NOT_FOUND: felt252 = 'Transaction not found';
}
