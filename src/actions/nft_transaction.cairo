//! This module implements the NFTTransaction component, which allows users to propose and execute
//! nft transactions.
//! It includes methods for proposing, retrieving, and executing nft transactions.
//!
//! The comment documentation of the public entrypoints can be found in the interface
//! `INFTTransaction`.

#[starknet::component]
pub mod NFTTransaction {
    use core::num::traits::Zero;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data::AccountData::InternalTrait;
    use spherre::components::permission_control;
    use spherre::components::treasury_handler;
    use spherre::components::treasury_handler::TreasuryHandler::InternalImpl as TreasuryHandlerInternalImpl;
    use spherre::components::treasury_handler::TreasuryHandler::InternalTrait as TreasuryHandlerInternalTrait;
    use spherre::components::treasury_handler::TreasuryHandler::TreasuryHandlerImpl;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::inft_tx::INFTTransaction;
    use spherre::interfaces::itreasury_handler::ITreasuryHandler;
    use spherre::types::{NFTTransactionData, Transaction};
    use spherre::types::{TransactionType};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_contract_address};

    #[storage]
    pub struct Storage {
        nft_transactions: Map<u256, NFTTransactionData>,
        nft_transaction_ids: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NFTTransactionProposed: NFTTransactionProposed,
        NFTTransactionExecuted: NFTTransactionExecuted,
    }

    #[derive(Drop, starknet::Event)]
    struct NFTTransactionProposed {
        id: u256,
        nft_contract: ContractAddress,
        token_id: u256,
        recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct NFTTransactionExecuted {
        id: u256,
        nft_contract: ContractAddress,
        token_id: u256,
        recipient: ContractAddress,
    }


    #[embeddable_as(NFTTransaction)]
    pub impl NFTTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
        impl TreasuryHandler: treasury_handler::TreasuryHandler::HasComponent<TContractState>,
    > of INFTTransaction<ComponentState<TContractState>> {
        fn propose_nft_transaction(
            ref self: ComponentState<TContractState>,
            nft_contract: ContractAddress,
            token_id: u256,
            recipient: ContractAddress,
        ) -> u256 {
            // Check that nft_contract and recipient are not zero addresses
            assert(nft_contract.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_NFT_CONTRACT);
            assert(recipient.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            // Check that the recipient address is not the account address
            let account_address = get_contract_address();
            assert(recipient != account_address, Errors::ERR_RECIPIENT_CANNOT_BE_ACCOUNT);
            // Verify NFT ownership
            let treasury_handler = get_dep_component!(@self, TreasuryHandler);
            assert(treasury_handler.is_nft_owner(nft_contract, token_id), Errors::ERR_NOT_OWNER);

            // Create the transaction in account data and get the id
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            let tx_id = account_data_comp.create_transaction(TransactionType::NFT_SEND);
            // Create the NFT transaction data
            let nft_tx_data = NFTTransactionData { nft_contract, token_id, recipient };
            // Save the NFT transaction data to storage
            self.nft_transactions.entry(tx_id).write(nft_tx_data);
            self.nft_transaction_ids.append().write(tx_id);
            // Emit event
            self.emit(NFTTransactionProposed { id: tx_id, nft_contract, token_id, recipient });
            tx_id
        }

        fn get_nft_transaction(
            self: @ComponentState<TContractState>, id: u256,
        ) -> NFTTransactionData {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(id);
            // Verify the transaction type
            assert(
                transaction.tx_type == TransactionType::NFT_SEND,
                Errors::ERR_INVALID_NFT_TRANSACTION,
            );
            self.nft_transactions.entry(id).read()
        }

        fn nft_transaction_list(
            self: @ComponentState<TContractState>,
        ) -> Array<NFTTransactionData> {
            let mut array: Array<NFTTransactionData> = array![];
            let range_stop = self.nft_transaction_ids.len();
            for index in 0..range_stop {
                let id = self.nft_transaction_ids.at(index).read();
                let tx = self.nft_transactions.entry(id).read();
                array.append(tx);
            };
            array
        }
        fn execute_nft_transaction(ref self: ComponentState<TContractState>, id: u256) {
            // Get the NFT transaction data (validation carried out)
            let nft_tx_data = self.get_nft_transaction(id);

            // Use TreasuryHandler for NFT ownership check
            let treasury_handler = get_dep_component!(@self, TreasuryHandler);
            assert(
                treasury_handler.is_nft_owner(nft_tx_data.nft_contract, nft_tx_data.token_id),
                Errors::ERR_NOT_OWNER,
            );
            // Execute the transaction
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            account_data_comp.execute_transaction(id);
            // Use TreasuryHandler for NFT transfer
            let mut treasury_handler_mut = get_dep_component_mut!(ref self, TreasuryHandler);
            treasury_handler_mut
                ._transfer_nft(
                    nft_tx_data.nft_contract, nft_tx_data.recipient, nft_tx_data.token_id,
                );
            // Emit event for successful execution
            self
                .emit(
                    NFTTransactionExecuted {
                        id,
                        nft_contract: nft_tx_data.nft_contract,
                        token_id: nft_tx_data.token_id,
                        recipient: nft_tx_data.recipient,
                    },
                );
        }
    }
}
