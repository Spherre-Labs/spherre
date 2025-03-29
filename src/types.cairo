use core::byte_array::ByteArray;
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
    pub id: u256,
    pub tx_type: TransactionType,
    pub tx_status: TransactionStatus,
    pub proposer: ContractAddress,
    pub executor: ContractAddress,
    pub approved: Span<ContractAddress>,
    pub rejected: Span<ContractAddress>,
    pub date_created: u64,
    pub date_executed: u64,
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub struct Member {
    address: ContractAddress,
    permissions: Span<PermissionEnum>,
}

#[derive(Drop, Serde, PartialEq)]
pub struct AccountDetails {
    pub name: ByteArray,
    pub description: ByteArray,
}
