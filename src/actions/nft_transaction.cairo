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
            assert(recipient.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            // Check that the recipient address is not the account address
            let account_address = get_contract_address();
            assert(recipient != account_address, Errors::ERR_RECIPIENT_CANNOT_BE_ACCOUNT);
            // Verify NFT ownership
            let erc721_dispatcher = IERC721Dispatcher { contract_address: nft_contract };
            assert(erc721_dispatcher.owner_of(token_id) == account_address, Errors::ERR_NOT_OWNER);
            // Check proposer permission
            let permission_control_comp = get_dep_component!(ref self, PermissionControl);
            assert(
                permission_control_comp.has_proposer_permission(get_caller_address()),
                Errors::ERR_NO_PROPOSER_PERMISSION
            );
            // Approve the account for future transfer
            erc721_dispatcher.approve(account_address, token_id);
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
// #[starknet::component]
// pub mod NFTTransaction {
//     use starknet::{ContractAddress, get_caller_address};
//     use spherre::types::NFTTransactionData;
//     use spherre::interfaces::IERC721;
//     use spherre::errors::NFTTransactionErrors;
//     use starknet::storage::{Map, Vec};
//     use starknet::event::EventEmitter;

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     pub struct NFTTransactionProposed {
//         transaction_id: u256,
//         nft_contract: ContractAddress,
//         token_id: u256,
//         recipient: ContractAddress,
//         proposer: ContractAddress
//     }

//     #[storage]
//     pub struct Storage {
//         nft_transaction: Map<u256, NFTTransactionData>,
//         nft_transaction_ids: Vec<u256>,
//         next_transaction_id: u256,
//     }

//     #[generate_trait]
//     pub trait NFTTransactionTrait {
//         fn propose_nft_transaction(
//             ref self: ComponentState<TContractState>,
//             nft_contract: ContractAddress,
//             token_id: u256,
//             recipient: ContractAddress
//         ) -> u256;

//         fn get_nft_transaction(
//             self: @ComponentState<TContractState>,
//             transaction_id: u256
//         ) -> Option<NFTTransactionData>;

//         fn get_all_nft_transactions(
//             self: @ComponentState<TContractState>
//         ) -> Array<NFTTransactionData>;
//     }

//     impl NFTTransactionImpl<
//         TContractState,
//         +HasComponent<TContractState>,
//         +Drop<TContractState>
//     > of NFTTransactionTrait {
//         fn propose_nft_transaction(
//             ref self: ComponentState<TContractState>,
//             nft_contract: ContractAddress,
//             token_id: u256,
//             recipient: ContractAddress
//         ) -> u256 {
//             // Validate inputs
//             assert(!nft_contract.is_zero(), NFTTransactionErrors::InvalidNFTContract);
//             assert(!recipient.is_zero(), NFTTransactionErrors::InvalidRecipient);

//             // Get caller
//             let proposer = get_caller_address();

//             // Verify caller has proposer permission
//             // TODO: Implement permission check

//             // Verify NFT ownership using IERC721 interface
//             let nft = IERC721::contract(nft_contract);
//             assert(
//                 nft.owner_of(token_id) == get_caller_address(),
//                 NFTTransactionErrors::NotNFTOwner
//             );

//             // Generate transaction ID
//             let transaction_id = self.next_transaction_id.read();
//             self.next_transaction_id.write(transaction_id + 1);

//             // Create and store transaction data
//             let transaction = NFTTransactionData {
//                 id: transaction_id,
//                 nft_contract,
//                 token_id,
//                 recipient,
//                 proposer,
//                 executed: false,
//                 timestamp: starknet::get_block_timestamp()
//             };

//             self.nft_transaction.write(transaction_id, transaction);
//             self.nft_transaction_ids.push(transaction_id);

//             // Emit event
//             self.emit(NFTTransactionProposed {
//                 transaction_id,
//                 nft_contract,
//                 token_id,
//                 recipient,
//                 proposer
//             });

//             transaction_id
//         }

//         fn get_nft_transaction(
//             self: @ComponentState<TContractState>,
//             transaction_id: u256
//         ) -> Option<NFTTransactionData> {
//             if self.nft_transaction.contains(transaction_id) {
//                 Option::Some(self.nft_transaction.read(transaction_id))
//             } else {
//                 Option::None
//             }
//         }

//         fn get_all_nft_transactions(
//             self: @ComponentState<TContractState>
//         ) -> Array<NFTTransactionData> {
//             let mut transactions = ArrayTrait::new();
//             let len = self.nft_transaction_ids.len();

//             let mut i: u32 = 0;
//             loop {
//                 if i >= len {
//                     break;
//                 }
//                 let id = self.nft_transaction_ids.get(i);
//                 transactions.append(self.nft_transaction.read(id));
//                 i += 1;
//             };

//             transactions
//         }
//     }
// }

//tests
// use core::array::ArrayTrait;
// use starknet::ContractAddress;
// use starknet::testing::{set_caller_address, set_contract_address};
// use spherre::test_utils::{setup_test, get_contract_address};
// use spherre::actions::nft_transaction::NFTTransaction;
// use spherre::types::NFTTransactionData;
// use spherre::errors::NFTTransactionErrors;
// use spherre::interfaces::IERC721;

// // Mock NFT contract for testing
// #[starknet::contract]
// mod MockERC721 {
//     use starknet::ContractAddress;

//     #[storage]
//     struct Storage {
//         owner: ContractAddress,
//         token_id: u256
//     }

//     #[external(v0)]
//     fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
//         self.owner.read()
//     }

//     #[external(v0)]
//     fn set_owner(ref self: ContractState, owner: ContractAddress) {
//         self.owner.write(owner);
//     }
// }

// #[test]
// fn test_propose_nft_transaction_success() {
//     // Setup
//     let (mut state, caller) = setup_test();
//     set_caller_address(caller);

//     // Deploy mock NFT contract
//     let mock_nft = deploy_mock_erc721();
//     mock_nft.set_owner(caller);

//     let recipient = get_contract_address('recipient');
//     let token_id = 1;

//     // Execute
//     let transaction_id = state.propose_nft_transaction(
//         mock_nft.contract_address,
//         token_id,
//         recipient
//     );

//     // Verify
//     let transaction = state.get_nft_transaction(transaction_id).unwrap();
//     assert(transaction.nft_contract == mock_nft.contract_address, 'Wrong NFT contract');
//     assert(transaction.token_id == token_id, 'Wrong token ID');
//     assert(transaction.recipient == recipient, 'Wrong recipient');
//     assert(transaction.proposer == caller, 'Wrong proposer');
//     assert(!transaction.executed, 'Should not be executed');
// }

// #[test]
// #[should_panic(expected: ('InvalidNFTContract',))]
// fn test_propose_nft_transaction_zero_contract() {
//     let (mut state, caller) = setup_test();
//     set_caller_address(caller);

//     state.propose_nft_transaction(
//         ContractAddress::zero(),
//         1,
//         get_contract_address('recipient')
//     );
// }

// #[test]
// #[should_panic(expected: ('InvalidRecipient',))]
// fn test_propose_nft_transaction_zero_recipient() {
//     let (mut state, caller) = setup_test();
//     set_caller_address(caller);

//     let mock_nft = deploy_mock_erc721();

//     state.propose_nft_transaction(
//         mock_nft.contract_address,
//         1,
//         ContractAddress::zero()
//     );
// }

// #[test]
// #[should_panic(expected: ('NotNFTOwner',))]
// fn test_propose_nft_transaction_not_owner() {
//     let (mut state, caller) = setup_test();
//     set_caller_address(caller);

//     let mock_nft = deploy_mock_erc721();
//     mock_nft.set_owner(get_contract_address('other_owner'));

//     state.propose_nft_transaction(
//         mock_nft.contract_address,
//         1,
//         get_contract_address('recipient')
//     );
// }

// #[test]
// fn test_get_nft_transaction_nonexistent() {
//     let (state, _) = setup_test();

//     let result = state.get_nft_transaction(999);
//     assert(result.is_none(), 'Should return None');
// }

// #[test]
// fn test_get_all_nft_transactions() {
//     // Setup
//     let (mut state, caller) = setup_test();
//     set_caller_address(caller);

//     let mock_nft = deploy_mock_erc721();
//     mock_nft.set_owner(caller);

//     // Propose multiple transactions
//     let recipient = get_contract_address('recipient');
//     state.propose_nft_transaction(mock_nft.contract_address, 1, recipient);
//     state.propose_nft_transaction(mock_nft.contract_address, 2, recipient);

//     // Verify
//     let transactions = state.get_all_nft_transactions();
//     assert(transactions.len() == 2, 'Wrong number of transactions');
// }

// // Helper function to deploy mock NFT contract
// fn deploy_mock_erc721() -> MockERC721 {
//     let calldata = array![];
//     let address = deploy_contract('MockERC721', calldata);
//     MockERC721 { contract_address: address }
// }


