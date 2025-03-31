use core::starknet::ContractAddress;
use spherre::types::{Transaction};

#[starknet::interface]
pub trait IAccountData<TContractState> {
    fn get_account_members(self: @TContractState) -> Array<ContractAddress>;
    fn get_members_count(self: @TContractState) -> u64;
    fn get_threshold(self: @TContractState) -> (u64, u64);
    fn get_transaction(self: @TContractState, transaction_id: u256) -> Transaction;
    fn is_member(self: @TContractState, address: ContractAddress) -> bool;
}
