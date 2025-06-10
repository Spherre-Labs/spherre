use starknet::ContractAddress;
use spherre::types::EditPermissionTransaction;

#[starknet::interface]
pub trait IEditPermissionTransaction<TContractState> {
fn propose_edit_permission_transaction(
    ref self: TContractState,
    member: ContractAddress,
    new_permissions: u8
) -> u256;

fn get_edit_permission_transaction(
    self: @TContractState,
    transaction_id: u256
) -> EditPermissionTransaction;


fn get_edit_permission_transaction_list(
    self: @TContractState
) -> Array<EditPermissionTransaction>;
}