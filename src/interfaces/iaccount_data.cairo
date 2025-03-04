use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAccountData<TContractState> {
    fn get_account_members(self: @TContractState) -> Array<ContractAddress>;
    fn add_member(ref self: TContractState, address: ContractAddress);
    fn get_members_count(self: @TContractState) -> u64;
}
