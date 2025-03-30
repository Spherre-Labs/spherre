pub mod Errors {
    pub const ERR_DEPLOYER_ZERO: felt252 = 'Deployer should not be zero';
    pub const ERR_OWNER_ZERO: felt252 = 'Owner should not be zero';
    pub const ERR_INVALID_MEMBER_THRESHOLD: felt252 = 'Members must meet threshold';
    pub const NON_ZERO_MEMBER_LENGTH: felt252 = 'Members count must be > 0';
    pub const INVALID_CALLER: felt252 = 'Can only renounce role for self';
    pub const MISSING_ROLE: felt252 = 'Caller is missing role';
    pub const ThresholdError: felt252 = 'Threshold is too high, lower it';
    pub const NON_ZERO_THRESHOLD: felt252 = 'Threshold must be > 0';
}
