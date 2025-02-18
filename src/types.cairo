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

#[derive(Drop, Copy)]
pub enum PermissionEnum {
    PROPOSER,
    VOTER,
    EXECUTOR
}

pub mod Permissions {
    pub const PROPOSER: felt252 = selector!("PROPOSER");
    pub const VOTER: felt252 = selector!("VOTER");
    pub const EXECUTOR: felt252 = selector!("EXECUTOR");
}
