use core::byte_array::ByteArray;
use spherre::types::AccountDetails;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn get_name(self: @TContractState) -> ByteArray;
    fn get_description(self: @TContractState) -> ByteArray;
    fn get_account_details(self: @TContractState) -> AccountDetails;

    // Add Ownable functions
    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);

    // Add the new functions that require owner access
    fn update_name(ref self: TContractState, new_name: ByteArray);
    fn update_description(ref self: TContractState, new_description: ByteArray);
}
