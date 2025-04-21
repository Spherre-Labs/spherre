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
    pub const ERR_INVALID_TRANSACTION: felt252 = 'Transaction is out of range';
    pub const ERR_TRANSACTION_NOT_VOTABLE: felt252 = 'Transaction is not votable';
    pub const ERR_CALLER_CANNOT_VOTE: felt252 = 'Caller cannot vote again';

    // Constants for the Ownable error format
    pub const ERR_NOT_OWNER_SELECTOR: felt252 =
        0x46a6158a16a947e5916b2a2ca68501a45e93d7110e81aa2d6438b1c57c879a3;
    pub const ERR_NOT_OWNER_PADDING: felt252 = 0x0;
    pub const ERR_NOT_OWNER_MESSAGE: felt252 = 0x43616c6c6572206973206e6f7420746865206f776e6572;
    pub const ERR_NOT_OWNER_MARKER: felt252 = 0x17;
}
