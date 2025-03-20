use starknet::ContractAddress;

#[derive(Drop, Copy, starknet::Store, PartialEq, Serde)]
pub enum TransactionStatus {
    #[default]
    VOID,
    INITIATED,
    REJECTED,
    APPROVED,
    EXECUTED,
}

#[derive(Drop, Copy, starknet::Store, PartialEq, Serde)]
pub enum TransactionType {
    #[default]
    VOID,
    MEMBER_ADD,
    MEMBER_REMOVE,
    MEMBER_PERMISSION_EDIT,
    THRESHOLD_CHANGE,
    TOKEN_SEND,
    NFT_SEND,
}

#[derive(Drop, Copy, PartialEq, Serde)]
pub enum PermissionEnum {
    PROPOSER,
    VOTER,
    EXECUTOR,
}

pub mod Permissions {
    pub const PROPOSER: felt252 = selector!("PROPOSER");
    pub const VOTER: felt252 = selector!("VOTER");
    pub const EXECUTOR: felt252 = selector!("EXECUTOR");
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub struct Transaction {
    id: u256,
    tx_type: TransactionType,
    tx_status: TransactionStatus,
    proposer: ContractAddress,
    executor: ContractAddress,
    approved: Span<ContractAddress>,
    rejected: Span<ContractAddress>,
    date_created: u64,
    date_executed: u64,
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub struct Member {
    address: ContractAddress,
    permissions: Span<PermissionEnum>
}
