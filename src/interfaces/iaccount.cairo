use core::byte_array::ByteArray;
use spherre::types::AccountDetails;
use starknet::{ContractAddress};

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn get_name(self: @TContractState) -> ByteArray;
    fn get_description(self: @TContractState) -> ByteArray;
    fn get_account_details(self: @TContractState) -> AccountDetails;
    fn get_deployer(self: @TContractState) -> ContractAddress;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}
