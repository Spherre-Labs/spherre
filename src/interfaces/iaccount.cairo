use core::byte_array::ByteArray;
use spherre::types::AccountDetails;
use starknet::{ContractAddress};

/// Interface for the SpherreAccount contract
/// This interface defines the entrypoints of the SpherreAccount contract.
/// It includes methods for retrieving account details, managing the account state
/// and interacting with the account.

#[starknet::interface]
pub trait IAccount<TContractState> {
    /// Retrieves the name of the account
    ///
    /// # Returns
    /// * `ByteArray` The name of the account as a byte array
    fn get_name(self: @TContractState) -> ByteArray;
    /// Retrieves the description of the account
    ///
    /// # Returns
    /// * `ByteArray` The description of the account as a byte array
    fn get_description(self: @TContractState) -> ByteArray;
    /// Retrieves the account details
    ///
    /// # Returns
    /// * `AccountDetails` The details of the account.
    fn get_account_details(self: @TContractState) -> AccountDetails;
    /// Retrieves the deployer of the account
    ///
    /// # Returns
    /// * `ContractAddress` The address of the account manager (the deployer).
    fn get_deployer(self: @TContractState) -> ContractAddress;
    /// Pauses the account contract
    ///
    /// # Panics
    /// This function raises an error if the caller is not the deployer.
    fn pause(ref self: TContractState);
    /// Unpauses the account contract
    ///
    /// # Panics
    /// This function raises an error if the caller is not the deployer.
    fn unpause(ref self: TContractState);
    /// Returns `IERC721_RECEIVER_ID` to confirm the receipt of an ERC721 token through safe
/// transfers.
/// This function is called when an ERC721 token is received by the Spherre contract.
///
/// # Parameters
/// * `operator` - The contract address of the operator who initiated the transfer.
/// * `from` - The contract address of the sender of the token.
/// * `token_id` - The ID of the ERC721 token being transferred.
/// * `data` - Additional data sent with the token transfer, as an Array of felts.
///
/// # Returns
/// * `felt252` - A value indicating the openzeppelin receiver (IERC721) ID.
///
/// # Panics
/// Safe receipt of ERC721 tokens panic if the contract does not implement the
/// `IERC721Receiver` interface or exposes the `IERC721ReceiverImpl`.
// fn on_erc721_received(
//     self: @TContractState,
//     operator: ContractAddress,
//     from: ContractAddress,
//     token_id: u256,
//     data: Span<felt252>,
// ) -> felt252;
}
