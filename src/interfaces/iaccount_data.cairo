use core::starknet::ContractAddress;
use spherre::types::{Transaction};

#[starknet::interface]
pub trait IAccountData<T> {
    fn get_account_members(self: @T) -> Array<ContractAddress>;
    fn get_members_count(self: @T) -> u64;
    fn get_threshold(self: @T) -> (u64, u64);
    fn get_transaction(self: @T, transaction_id: u256) -> Transaction;
    fn is_member(self: @T, address: ContractAddress) -> bool;
    fn get_number_of_voters(self: @T) -> u64;
    fn get_number_of_proposers(self: @T) -> u64;
    fn get_number_of_executors(self: @T) -> u64;
    fn approve_transaction(ref self: T, tx_id: u256);
    fn reject_transaction(ref self: T, tx_id: u256);
}
