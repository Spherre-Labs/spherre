use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};
use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use spherre::tests::mocks::mock_account_data::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use spherre::tests::mocks::mock_nft::{IMockNFTDispatcher, IMockNFTDispatcherTrait};
use spherre::types::TransactionType;
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_nft() -> IERC721Dispatcher {
    let contract_class = declare("MockNFT").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IERC721Dispatcher { contract_address }
}

fn deploy_mock_contract() -> IMockContractDispatcher {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMockContractDispatcher { contract_address }
}

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn recipient() -> ContractAddress {
    contract_address_const::<'recipient'>()
}

#[test]
fn test_propose_nft_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction functionality
    // Add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign proposer role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Checks
    // Get transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    // Check that the transaction type is NFT_SEND
    assert(transaction.tx_type == TransactionType::NFT_SEND, 'Invalid Transaction');
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(nft_transaction.nft_contract == nft.contract_address, 'Contract Address Invalid');
    assert(nft_transaction.token_id == token_id, 'Token ID is Invalid');
    assert(nft_transaction.recipient == receiver, 'Recipient is Invalid');
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_nft_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction
    // Add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // No proposer role assigned
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Not NFT owner')]
fn test_propose_nft_transaction_fail_if_not_owner() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to a different address (not the contract)
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(caller, token_id);

    // Propose transaction
    // Add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign proposer role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose transaction
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient cannot be account')]
fn test_propose_nft_transaction_fail_if_recipient_is_account() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = mock_contract.contract_address;

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction
    // Add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign proposer role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose transaction
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Non-zero address required')]
fn test_propose_nft_transaction_fail_if_nft_contract_zero() {
    let mock_contract = deploy_mock_contract();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Propose transaction with zero NFT contract address
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract
        .propose_nft_transaction_pub(contract_address_const::<0>(), token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Non-zero address required')]
fn test_propose_nft_transaction_fail_if_recipient_zero() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction with zero recipient address
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, contract_address_const::<0>()); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}