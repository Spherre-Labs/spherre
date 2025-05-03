#[starknet::component]
pub mod NFTTransaction {
    use core::num::traits::Zero;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data::AccountData::InternalTrait;
    use spherre::account_data;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use spherre::interfaces::inft_tx::INFTTransaction;
    use spherre::types::{NFTTransactionData, Transaction};
    use spherre::types::{TransactionType};
    use starknet::storage::{
        Map, StoragePathEntry, Vec, VecTrait, MutableVecTrait, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use starknet::{ContractAddress, get_contract_address};

    #[storage]
    pub struct Storage {
        nft_transactions: Map<u256, NFTTransactionData>,
        nft_transaction_ids: Vec<u256>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NFTTransactionCreated: NFTTransactionCreated
    }

    #[derive(Drop, starknet::Event)]
    struct NFTTransactionCreated {
        id: u256,
        nft_contract: ContractAddress,
        token_id: u256,
        recipient: ContractAddress
    }

    #[embeddable_as(NFTTransaction)]
    pub impl NFTTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of INFTTransaction<ComponentState<TContractState>> {
        fn propose_nft_transaction(
            ref self: ComponentState<TContractState>,
            nft_contract: ContractAddress,
            token_id: u256,
            recipient: ContractAddress
        ) -> u256 {
            // Check that nft_contract and recipient are not zero addresses
            assert(nft_contract.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_NFT_CONTRACT);
             // Validate token ID
            assert(token_id.is_non_zero(), Errors::ERR_INVALID_TOKEN_ID);
            assert(recipient.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            // Check that the recipient address is not the account address
            let account_address = get_contract_address();
            assert(recipient != account_address, Errors::ERR_RECIPIENT_CANNOT_BE_ACCOUNT);
            // Verify NFT ownership
            let erc721_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            assert(erc721_dispatcher.owner_of(token_id) == account_address, Errors::ERR_NOT_OWNER);

            // Create the transaction in account data and get the id
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            let tx_id = account_data_comp.create_transaction(TransactionType::NFT_SEND);
            // Create the NFT transaction data
            let nft_tx_data = NFTTransactionData { nft_contract, token_id, recipient };
            // Save the NFT transaction data to storage
            self.nft_transactions.entry(tx_id).write(nft_tx_data);
            self.nft_transaction_ids.append().write(tx_id);
            // Emit event
            self.emit(NFTTransactionCreated { id: tx_id, nft_contract, token_id, recipient });
            tx_id
        }

        fn get_nft_transaction(
            self: @ComponentState<TContractState>, id: u256
        ) -> NFTTransactionData {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(id);
            // Verify the transaction type
            assert(
                transaction.tx_type == TransactionType::NFT_SEND,
                Errors::ERR_INVALID_NFT_TRANSACTION
            );
            self.nft_transactions.entry(id).read()
        }

        fn nft_transaction_list(
            self: @ComponentState<TContractState>
        ) -> Array<NFTTransactionData> {
            let mut array: Array<NFTTransactionData> = array![];
            let range_stop = self.nft_transaction_ids.len();
            for index in 0
                ..range_stop {
                    let id = self.nft_transaction_ids.at(index).read();
                    let tx = self.nft_transactions.entry(id).read();
                    array.append(tx);
                };
            array
        }
    }
}
