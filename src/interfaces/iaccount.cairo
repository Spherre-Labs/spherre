use starknet::ContractAddress;
use core::byte_array::ByteArray;
use spherre::types::AccountDetails;

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn get_name(self: @TContractState) -> ByteArray;
    fn get_description(self: @TContractState) -> ByteArray;
    fn get_account_details(self: @TContractState) -> AccountDetails;
}
