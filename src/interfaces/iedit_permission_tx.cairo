use spherre::types::EditPermissionTransaction;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IEditPermissionTransaction<TContractState> {
    /// Proposes a transaction to edit permissions for a member.
    /// Returns the transaction ID.
    ///
    /// # Parameters
    /// *`member`* - The address of the member whose permissions are being edited.
    /// *`new_permissions`* - The new permissions to be set for the member, represented as a u8
    /// mask.
    ///
    /// # Returns
    /// A unique transaction ID (u256) for the proposed edit permission transaction.
    fn propose_edit_permission_transaction(
        ref self: TContractState, member: ContractAddress, new_permissions: u8
    ) -> u256;
    /// Retrieves the details of a specific edit permission transaction by its ID.
    ///
    /// # Parameters
    /// *`transaction_id`* - The ID of the transaction to retrieve.
    ///
    /// # Returns
    /// An `EditPermissionTransaction` object containing the details of the transaction.
    fn get_edit_permission_transaction(
        self: @TContractState, transaction_id: u256
    ) -> EditPermissionTransaction;
    /// Retrieves a list of all edit permission transactions.
    ///
    /// # Returns
    /// An array of `EditPermissionTransaction` objects representing all edit permission
    /// transactions.
    fn get_edit_permission_transaction_list(
        self: @TContractState
    ) -> Array<EditPermissionTransaction>;
}
