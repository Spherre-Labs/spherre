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
    SMART_TOKEN_LOCK,
}

#[derive(Drop, Copy, PartialEq, Serde)]
pub enum PermissionEnum {
    PROPOSER,
    VOTER,
    EXECUTOR,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Hash)]
pub enum FeesType {
    PROPOSAL_FEE,
    VOTING_FEE,
    EXECUTION_FEE,
    DEPLOYMENT_FEE,
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

#[derive(Drop, Copy, starknet::Store, PartialEq, Serde)]
pub enum LockStatus {
    #[default]
    LOCKED,
    PAIDOUT,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct SmartTokenLock {
    pub token: ContractAddress,
    pub date_locked: u64,
    pub lock_duration: u64, // Number of days till token unlock
    pub token_amount: u256,
    pub lock_status: LockStatus,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct EditPermissionTransaction {
    pub member: ContractAddress,
    pub new_permissions: u8
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SmartTokenLockTransaction {
    pub token: ContractAddress,
    pub amount: u256,
    pub duration: u64,
    pub transaction_id: u256,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct MemberDetails {
    pub address: ContractAddress,
    pub proposed_count: u256,
    pub approved_count: u256,
    pub rejected_count: u256,
    pub executed_count: u256,
    pub date_joined: u64,
}


#[derive(Drop, Serde, Copy)]
pub struct WillData {
    expiration_timestamp: u64,  
    beneficiary: ContractAddress,  
    is_active: bool,  
    last_reset_timestamp: u64,  
    reset_count: u32,  
    threshold: u8,  
}