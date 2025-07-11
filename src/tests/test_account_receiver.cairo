#[cfg(test)]
mod tests {
    // use super::*;
    // use openzeppelin::token::erc721::ERC721Receiver;
    use crate::account::{SpherreAccount, SpherreAccount::AccountImpl};
    use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
    use openzeppelin::introspection::interface::ISRC5_ID;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin::token::erc721::interface::{IERC721_RECEIVER_ID, IERC721Receiver,};
    use snforge_std::{
        declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
        DeclareResultTrait, test_address
    };
    use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use spherre::tests::mocks::mock_account_data::{IMockContractDispatcher};
    use spherre::tests::mocks::mock_nft::{IMockNFTDispatcher, IMockNFTDispatcherTrait};
    use starknet::{ContractAddress, contract_address_const};

    // Constants for testing
    fn OWNER() -> ContractAddress {
        contract_address_const::<'Owner'>()
    }
    fn OPERATOR() -> ContractAddress {
        contract_address_const::<'Operator'>()
    }
    const TOKEN_ID: u256 = 1;

    // Helper function to set up test contract
    fn setup_test_contract() -> SpherreAccount::ContractState {
        let owner = OWNER();

        let mut contract_state = SpherreAccount::contract_state_for_testing();

        SpherreAccount::constructor(
            ref contract_state,
            contract_address_const::<2>(), // deployer
            owner, // owner
            "TestAccount", // name
            "TestDescription", // description
            array![contract_address_const::<3>()], // members
            1, // threshold
        );

        contract_state
    }

    // setting up the contract state
    fn CONTRACT_STATE() -> SpherreAccount::ContractState {
        SpherreAccount::contract_state_for_testing()
    }

    fn deploy_mock_erc721() -> IERC721Dispatcher {
        let contract_class = declare("MockNFT").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
        IERC721Dispatcher { contract_address }
    }

    // Helper function to deploy SpherreAccount contract (for integration tests as a recipient)
    fn deploy_account() -> IAccountDispatcher {
        let contract = declare("SpherreAccount").unwrap().contract_class();

        let owner = OWNER();
        let deployer: ContractAddress = contract_address_const::<'deployer'>();
        let members: Array<ContractAddress> = array![
            contract_address_const::<'member1'>(), contract_address_const::<'member2'>()
        ];
        let threshold: u64 = 1;
        let name: ByteArray = "SpherreTestAccount";
        let description: ByteArray = "SpherreTestingAccount";

        let mut constructor_calldata = array![];
        deployer.serialize(ref constructor_calldata);
        owner.serialize(ref constructor_calldata);
        name.serialize(ref constructor_calldata);
        description.serialize(ref constructor_calldata);
        members.serialize(ref constructor_calldata);
        threshold.serialize(ref constructor_calldata);

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        IAccountDispatcher { contract_address }
    }

    // Helper function to deploy a mock contract that does not implement IERC721Receiver
    fn deploy_mock_contract() -> IMockContractDispatcher {
        let contract_class = declare("MockContract").unwrap().contract_class();
        let mut calldata = array![];
        let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
        IMockContractDispatcher { contract_address }
    }

    // --- Unit tests for core Spherre receiver functionality ---

    #[test]
    fn test_initial_state() {
        let contract_state = setup_test_contract();

        // Verify interface support
        let supports_ierc721_receiver = contract_state.src5.supports_interface(IERC721_RECEIVER_ID);
        assert!(supports_ierc721_receiver, "ERC721Receiver interface not supported");

        let supports_isrc5 = contract_state.src5.supports_interface(ISRC5_ID);
        assert!(supports_isrc5, "SRC5 interface not supported");
    }

    #[test]
    fn test_on_erc721_received() {
        let contract_state = setup_test_contract();

        // Test with empty data
        let empty_data = array![].span();
        let result: felt252 = contract_state
            .erc721_receiver
            .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, empty_data);
        assert_eq!(result, IERC721_RECEIVER_ID, "Should return ERC721Receiver interface ID");

        // Test with some data
        let with_data = array![123.into(), 456.into()].span();
        let result_with_data: felt252 = contract_state
            .erc721_receiver
            .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, with_data);
        assert_eq!(
            result_with_data, IERC721_RECEIVER_ID, "Should also return ERC721Receiver interface ID"
        );
    }

    // --- Integration tests for ERC721 safe transfers scenarios ---

    #[test]
    fn test_owner_safe_transfer_to_spherre_account() {
        let erc721_contract = deploy_mock_erc721();
        let spherre_contract = deploy_account();
        let minter = OWNER();

        // Mint a token to the owner
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        IMockNFTDispatcher { contract_address: erc721_contract.contract_address }
            .mint(minter, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Verify owner is the minter initially
        let initial_owner = erc721_contract.owner_of(TOKEN_ID);
        assert_eq!(initial_owner, minter, "Initial owner should be minter");

        // Safe transfer from to Spherre
        let data = array![].span(); // Empty data is valid
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        erc721_contract
            .safe_transfer_from(minter, spherre_contract.contract_address, TOKEN_ID, data);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Verify that Spherre contract now owns the token
        let new_owner = erc721_contract.owner_of(TOKEN_ID);
        assert_eq!(
            new_owner, spherre_contract.contract_address, "Spherre contract should own the token"
        );
    }

    #[test]
    fn test_approved_safe_transfer_to_spherre_account() {
        let erc721_contract = deploy_mock_erc721();
        let spherre_contract = deploy_account();
        let minter = OWNER();
        let operator = OPERATOR();

        // Mint a token to the owner
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        IMockNFTDispatcher { contract_address: erc721_contract.contract_address }
            .mint(minter, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Verify owner is the minter initially
        let initial_owner = erc721_contract.owner_of(TOKEN_ID);
        assert_eq!(initial_owner, minter, "Initial owner should be minter");

        // Approve Operator to transfer the token
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        erc721_contract.approve(operator, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Safe transfer from to Spherre
        // Caller must be owner or approved
        let data = array![123.into()].span(); // Empty data also transfers successfully
        start_cheat_caller_address(erc721_contract.contract_address, operator);
        erc721_contract
            .safe_transfer_from(minter, spherre_contract.contract_address, TOKEN_ID, data);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Verify that Spherre contract now owns the token
        let new_owner = erc721_contract.owner_of(TOKEN_ID);
        assert_eq!(
            new_owner, spherre_contract.contract_address, "Spherre contract should own the token"
        );
    }

    #[test]
    #[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
    fn test_approved_safe_transfer_to_invalid_receiver() {
        let erc721_contract = deploy_mock_erc721();
        let minter = OWNER();
        let operator = OPERATOR();

        // Mint a token to the owner
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        IMockNFTDispatcher { contract_address: erc721_contract.contract_address }
            .mint(minter, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Approve Operator to transfer the token
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        erc721_contract.approve(operator, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Attempt to safe transfer to an invalid receiver (not implementing IERC721Receiver)
        start_cheat_caller_address(erc721_contract.contract_address, operator);
        let data = array![123.into()].span();
        let invalid_receiver = deploy_mock_contract().contract_address;

        erc721_contract.safe_transfer_from(minter, invalid_receiver, TOKEN_ID, data);
    }

    #[test]
    #[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
    fn test_approved_safe_transfer_to_spherre_account_no_receiver() {
        let erc721_contract = deploy_mock_erc721();
        let account_contract = test_address();
        let minter = OWNER();
        let operator = OPERATOR();

        // Mint a token to the owner
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        IMockNFTDispatcher { contract_address: erc721_contract.contract_address }
            .mint(minter, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Approve Operator to transfer the token
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        erc721_contract.approve(operator, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Attempt to safe transfer to Spherre contract (not implementing IERC721Receiver)
        start_cheat_caller_address(erc721_contract.contract_address, operator);
        let data = array![123.into()].span();

        // This should panic as the receiver doesn't properly implement the interface
        erc721_contract.safe_transfer_from(minter, account_contract, TOKEN_ID, data);
    }

    #[test]
    fn test_spherre_account_receives_token_when_paused() {
        let erc721_contract = deploy_mock_erc721();
        let spherre_contract = deploy_account();
        let minter = OWNER();
        let operator = OPERATOR();

        // Mint a token to the owner
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        IMockNFTDispatcher { contract_address: erc721_contract.contract_address }
            .mint(minter, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Approve Operator to transfer the token
        start_cheat_caller_address(erc721_contract.contract_address, minter);
        erc721_contract.approve(operator, TOKEN_ID);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Pause the Spherre contract
        let deployer = spherre_contract.get_deployer();
        start_cheat_caller_address(spherre_contract.contract_address, deployer);
        spherre_contract.pause();
        stop_cheat_caller_address(spherre_contract.contract_address);

        // Safe transfer from to Spherre after paused
        let data = array![123.into()].span();
        start_cheat_caller_address(erc721_contract.contract_address, operator);
        erc721_contract
            .safe_transfer_from(minter, spherre_contract.contract_address, TOKEN_ID, data);
        stop_cheat_caller_address(erc721_contract.contract_address);

        // Verify that Spherre contract now owns the token
        let new_owner = erc721_contract.owner_of(TOKEN_ID);
        assert_eq!(
            new_owner, spherre_contract.contract_address, "Should receive tokens even when paused"
        );
    }
}
