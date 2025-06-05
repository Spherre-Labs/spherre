use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait ISpherre<TContractState> {
    fn grant_superadmin_role(ref self: TContractState, account: ContractAddress);
    fn grant_staff_role(ref self: TContractState, account: ContractAddress);
    fn revoke_superadmin_role(ref self: TContractState, account: ContractAddress);
    fn revoke_staff_role(ref self: TContractState, account: ContractAddress);
    fn has_staff_role(self: @TContractState, account: ContractAddress) -> bool;
    fn has_superadmin_role(self: @TContractState, account: ContractAddress) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    // New functions for class hash management
    fn update_account_class_hash(ref self: TContractState, new_class_hash: ClassHash);
    fn get_account_class_hash(self: @TContractState) -> ClassHash;
}
