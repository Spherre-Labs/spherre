use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAccountData<TContractState> {
    fn get_account_members(self: @TContractState) -> Array<ContractAddress>;
}
