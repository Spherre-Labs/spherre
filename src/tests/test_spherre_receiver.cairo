#[cfg(test)]
mod tests {
    // use super::*;
    // use openzeppelin::token::erc721::ERC721Receiver;
    use crate::spherre::{Spherre, Spherre::SpherreImpl};
    use openzeppelin::token::erc721::interface::{
        IERC721_RECEIVER_ID, IERC721Receiver,
    };
    use openzeppelin::introspection::interface::ISRC5_ID;
    use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
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
    fn setup_test_contract() -> Spherre::ContractState {
        let owner = OWNER();

        let mut contract_state = Spherre::contract_state_for_testing();
        
        Spherre::constructor(ref contract_state, owner);

        contract_state
    }

    // setting up the contract state
    fn CONTRACT_STATE() -> Spherre::ContractState {
        Spherre::contract_state_for_testing()
    }

    #[test]
    fn initial_state() {
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
        let result: felt252 = contract_state.erc721_receiver.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, empty_data);
        assert_eq!(
            result,
            IERC721_RECEIVER_ID,
            "Should return ERC721Receiver interface ID"
        );

        // Test with some data
        let with_data = array![123.into(), 456.into()].span();
        let result_with_data: felt252 = contract_state.erc721_receiver.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID,
        with_data);
        assert_eq!(
            result_with_data,
            IERC721_RECEIVER_ID,
            "Should also return ERC721Receiver interface ID"
        );
    }


}
