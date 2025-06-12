use starknet::ContractAddress;

/// Interface for the ERC721 standard
/// This interface defines the entrypoints of the ERC721 token contract.
/// It includes methods for retrieving token details, managing ownership,
/// and handling token transfers and approvals.

#[starknet::interface]
pub trait IERC721<TContractState> {
    /// Retrieves the balance of a specific account
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to check the balance for
    ///
    /// # Returns
    /// * `u256` The number of tokens owned by the specified account
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    /// Retrieves the owner of a specific token
    ///
    /// # Parameters
    /// * `token_id` - The unique identifier of the token
    ///
    /// # Returns
    /// * `ContractAddress` The contract address of the owner of the specified token
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    /// Safely transfers a token from one account to another
    ///
    /// # Parameters
    /// * `from` - The contract address of the current owner of the token
    /// * `to` - The contract address of the recipient
    /// * `token_id` - The unique identifier of the token to transfer
    /// * `data` - Additional data to pass with the transfer (optional)
    ///
    /// # Panics
    /// This function raises an error if the caller is not the owner of the token or approved to
    /// transfer it.
    /// This function raises an error if the recipient is not a valid contract or does not implement
    /// the `IERC721Receiver` interface.
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    /// Transfers a token from one account to another
    ///
    /// # Parameters
    /// * `from` - The contract address of the current owner of the token
    /// * `to` - The contract address of the recipient
    /// * `token_id` - The unique identifier of the token to transfer
    ///
    /// # Panics
    /// This function raises an error if the caller is not the owner of the token or approved to
    /// transfer it.
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    /// Approves a specific account to transfer a token on behalf of the owner
    ///
    /// # Parameters
    /// * `to` - The contract address of the account to approve for transferring the token
    /// * `token_id` - The unique identifier of the token to approve for transfer
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    /// Sets or unsets the approval for an operator to manage all tokens of the caller
    ///
    /// # Parameters
    /// * `operator` - The contract address of the operator to set or unset approval for
    /// * `approved` - A boolean indicating whether to approve or revoke the operator's approval
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    /// Retrieves the approved account for a specific token
    ///
    /// # Parameters
    /// * `token_id` - The unique identifier of the token
    ///
    /// # Returns
    /// * `ContractAddress` The contract address of the approved account for the specified token
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    /// Checks if an operator is approved to manage all tokens of a specific owner
    ///
    /// # Parameters
    /// * `owner` - The contract address of the owner of the tokens
    /// * `operator` - The contract address of the operator to check approval for
    ///
    /// # Returns
    /// * `bool` A boolean indicating whether the operator is approved to manage all tokens of the
    /// owner
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;

    // IERC721Metadata

    /// Retrieves the name of the token
    ///
    /// # Returns
    /// * `ByteArray` The name of the token as a byte array
    fn name(self: @TContractState) -> ByteArray;
    /// Retrieves the symbol of the token
    ///
    /// # Returns
    /// * `ByteArray` The symbol of the token as a byte array
    fn symbol(self: @TContractState) -> ByteArray;
    /// Retrieves the URI for a specific token
    ///
    /// # Parameters
    /// * `token_id` - The unique identifier of the token
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
}
