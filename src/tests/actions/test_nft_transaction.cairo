use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait
};
use spherre::interfaces::ierc721::{IERC721Dispatcher};
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

fn zero_address() -> ContractAddress {
    contract_address_const::<'0'>()
}


#[test]
fn test_propose_nft_transaction_successful() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Verify transaction
    let transaction = mock_contract.get_transaction_pub(tx_id);
    assert(transaction.tx_type == TransactionType::NFT_SEND, 'Invalid Transaction');
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(nft_transaction.nft_contract == nft_contract.contract_address, 'NFT Contract Invalid');
    assert(nft_transaction.token_id == token_id, 'Token ID Invalid');
    assert(nft_transaction.recipient == receiver, 'Recipient Invalid');
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT for account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Propose Transaction
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_propose_transaction_fail_if_not_owner() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT for a different address (caller)
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(caller, token_id);

    // Propose transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient cannot be account')]
fn test_propose_transaction_fail_if_recipient_is_account() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = mock_contract.contract_address;

    // Mint NFT for account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'NFT contract address is zero')]
fn test_propose_transaction_fail_if_nft_contract_address_is_zero() {
    let mock_contract = deploy_mock_contract();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Propose transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_nft_transaction_pub(
            contract_address_const::<0>(), token_id, receiver
        ); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient address is zero')]
fn test_propose_transaction_fail_if_recipient_zero() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();

    // Mint NFT for account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_nft_transaction_pub(
            nft.contract_address, token_id, contract_address_const::<0>()
        ); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token ID is invalid')]
fn test_propose_transaction_fail_if_token_id_zero() {
    let mock_contract = deploy_mock_contract();
    let nft = deploy_mock_nft();
    let token_id: u256 = 0;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT for account
    let mock_nft = IMockNFTDispatcher { contract_address: nft.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Propose transaction
    // add member
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    // Assign Proposer Role
    mock_contract.assign_proposer_permission_pub(caller);
    // Propose Transaction
    mock_contract
        .propose_nft_transaction_pub(nft.contract_address, token_id, receiver); // should panic
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not a proposer')]
fn test_propose_nft_transaction_fail_if_not_proposer() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member but do not assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);

    // Propose NFT transaction (should fail)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

// #[test]
// #[should_panic(expected: 'Non-zero address')]
// fn test_propose_nft_transaction_fail_if_nft_contract_zero() {
//     let mock_contract = deploy_mock_contract();
//     let nft_contract = deploy_mock_nft();
//     let token_id: u256 = 1;
//     let caller: ContractAddress = owner();
//     let receiver: ContractAddress = recipient();

//     // Mint NFT to account
//     let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
//     mock_nft.mint(mock_contract.contract_address, token_id);

//     // Add member and assign proposer role
//     start_cheat_caller_address(mock_contract.contract_address, caller);
//     mock_contract.add_member_pub(caller);
//     mock_contract.assign_proposer_permission_pub(caller);

//     // Propose NFT transaction with zero NFT contract address
//     mock_contract.propose_nft_transaction_pub(zero_address(), token_id, receiver);
//     stop_cheat_caller_address(mock_contract.contract_address);
// }

#[test]
#[should_panic(expected: 'Non-zero address')]
fn test_propose_nft_transaction_fail_if_recipient_zero() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero recipient address
    mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, zero_address());
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token ID is invalid')]
fn test_propose_nft_transaction_fail_if_token_id_zero() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 0;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, 1); // Mint a different token ID

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with zero token ID
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Recipient cannot be account')]
fn test_propose_nft_transaction_fail_if_recipient_is_account() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = mock_contract.contract_address;

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction with recipient as account
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_propose_nft_transaction_fail_if_not_owner() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();
    let other_account: ContractAddress = contract_address_const::<'other'>();

    // Mint NFT to a different account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(other_account, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction (should fail as account does not own NFT)
    mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_get_nft_transaction() {
    let mock_contract = deploy_mock_contract();
    let nft_contract = deploy_mock_nft();
    let token_id: u256 = 1;
    let caller: ContractAddress = owner();
    let receiver: ContractAddress = recipient();

    // Mint NFT to account
    let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
    mock_nft.mint(mock_contract.contract_address, token_id);

    // Add member and assign proposer role
    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member_pub(caller);
    mock_contract.assign_proposer_permission_pub(caller);

    // Propose NFT transaction
    let tx_id = mock_contract
        .propose_nft_transaction_pub(nft_contract.contract_address, token_id, receiver);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Retrieve and verify transaction
    let nft_transaction = mock_contract.get_nft_transaction_pub(tx_id);
    assert(nft_transaction.nft_contract == nft_contract.contract_address, 'NFT Contract Invalid');
    assert(nft_transaction.token_id == token_id, 'Token ID Invalid');
    assert(nft_transaction.recipient == receiver, 'Recipient Invalid');
}
// #[test]
// fn test_nft_transaction_list() {
//     let mock_contract = deploy_mock_contract();
//     let nft_contract = deploy_mock_nft();
//     let caller: ContractAddress = owner();
//     let receiver: ContractAddress = recipient();

//     // Mint two NFTs to account
//     let mock_nft = IMockNFTDispatcher { contract_address: nft_contract.contract_address };
//     mock_nft.mint(mock_contract.contract_address, 1);
//     mock_nft.mint(mock_contract.contract_address, 2);

//     // Add member and assign proposer role
//     start_cheat_caller_address(mock_contract.contract_address, caller);
//     mock_contract.add_member_pub(caller);
//     mock_contract.assign_proposer_permission_pub(caller);

//     // Propose two NFT transactions
//     mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, 1, receiver);
//     mock_contract.propose_nft_transaction_pub(nft_contract.contract_address, 2, receiver);
//     stop_cheat_caller_address(mock_contract.contract_address);

//     // Retrieve transaction list
//     let tx_list = mock_contract.nft_transaction_list_pub();
//     assert(tx_list.len() == 2, 'Invalid transaction list length');
//     assert(tx_list.at(0).nft_contract == nft_contract.contract_address, 'NFT Contract 1
//     Invalid');
//     assert(tx_list.at(0).token_id == 1, 'Token ID 1 Invalid');
//     assert(tx_list.at(0).recipient == receiver, 'Recipient 1 Invalid');
//     assert(tx_list.at(1).nft_contract == nft_contract.contract_address, 'NFT Contract 2
//     Invalid');
//     assert(tx_list.at(1).token_id == 2, 'Token ID 2 Invalid');
//     assert(tx_list.at(1).recipient == receiver, 'Recipient 2 Invalid');
// }


