#[derive(Drop, Copy, starknet::Store)]
pub enum TransactionStatus {
    #[default]
    VOID,
    INITIATED,
    REJECTED,
    APPROVED,
    EXECUTED
}

#[derive(Drop, Copy, starknet::Store)]
pub enum TransactionType {
    #[default]
    VOID,
    MEMBER_ADD,
    MEMBER_REMOVE,
    MEMBER_PERMISSION_EDIT,
    THRESHOLD_CHANGE,
    TOKEN_SEND,
    NFT_SEND
}
/// Module defining permission constants
pub mod Permissions {
    /// PROPOSER role identifier
    pub const PROPOSER: felt252 = selector!("PROPOSER");

    /// VOTER role identifier
    pub const VOTER: felt252 = selector!("VOTER");

    /// EXECUTOR role identifier
    pub const EXECUTOR: felt252 = selector!("EXECUTOR");
}