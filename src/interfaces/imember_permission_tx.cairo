use starknet::ContractAddress;

pub trait IMemberPermissionTransaction<TContractState> {
fn propose_member_permission_transaction(
    ref self: TContractState,
    member: ContractAddress,
    new_permissions: u8
) -> u256;

fn get_member_permission_transaction(
    self: @TContractState,
    transaction_id: u256
) -> (ContractAddress, u8);
}