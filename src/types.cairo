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

pub trait PermissionTrait {
    fn to_mask(self: PermissionEnum) -> u8;
    fn has_permission_from_mask(self: PermissionEnum, mask: u8) -> bool;
}

pub impl PermissionEmumImpl of PermissionTrait {
    fn to_mask(self: PermissionEnum) -> u8 {
        match self {
            PermissionEnum::PROPOSER => 1_u8, // 1 << 0
            PermissionEnum::VOTER => 2_u8, // 1 << 1
            PermissionEnum::EXECUTOR => 4_u8, // 1 << 2
        }
    }
    fn has_permission_from_mask(self: PermissionEnum, mask: u8) -> bool {
        let permission_bit = self.to_mask();
        (mask & permission_bit) != 0_u8
    }
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
    permissions: Span<PermissionEnum>
}

#[derive(Drop, Serde, PartialEq)]
pub struct AccountDetails {
    pub name: ByteArray,
    pub description: ByteArray
}

///
///  ACTIONS DATA STRUCTURES
///
#[derive(Drop, Serde, starknet::Store)]
pub struct TokenTransactionData {
    pub token: ContractAddress,
    pub amount: u256,
    pub recipient: ContractAddress
}
#[derive(Drop, Serde, starknet::Store)]
pub struct NFTTransactionData {
    pub nft_contract: ContractAddress,
    pub token_id: u256,
    pub recipient: ContractAddress
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ThresholdChangeData {
    pub new_threshold: u64
}

#[derive(Drop, Serde)]
pub struct EditPermissionData {
    pub member: ContractAddress,
    pub permissions: Array<PermissionEnum>
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MemberRemoveData {
    pub member_address: ContractAddress,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MemberAddData {
    pub member: ContractAddress,
    pub permissions: u8
}

pub mod SpherreAdminRoles {
    pub const SUPERADMIN: felt252 = selector!("SUPERADMIN");
    pub const STAFF: felt252 = selector!("STAFF");
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct EditPermissionTransaction {
    pub member: ContractAddress,
    pub new_permissions: u8
}
