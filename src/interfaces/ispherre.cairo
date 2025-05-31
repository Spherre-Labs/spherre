use starknet::ContractAddress;

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
    fn deploy_account(
        ref self: TContractState,
        owner: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        members: Array<ContractAddress>,
        threshold: u64
    ) -> ContractAddress;
    fn is_deployed_account(self: @TContractState, account: ContractAddress) -> bool;
}
