use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use starknet::{ContractAddress, get_caller_address};
use debug::PrintTrait;

use spherre::components::security::SecurityComponent;
use spherre::interfaces::icomponents::IComponents;

#[starknet::contract]
mod TestSecurity {
    use super::SecurityComponent;
    use starknet::ContractAddress;

    component!(path: SecurityComponent, storage: security, event: SecurityEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        security: SecurityComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SecurityEvent: SecurityComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.security.initializer(owner);
    }
}

#[test]
fn test_security_component() {
    // Deploy the contract
    let owner = starknet::contract_address_const::<0x1>();
    let contract = TestSecurity::deploy(owner).unwrap();

    // Test ownership
    assert(contract.owner() == owner, 'Owner should be set correctly');

    // Test pausing
    assert(!contract.paused(), 'Should not be paused initially');
    contract.pause();
    assert(contract.paused(), 'Should be paused');
    contract.unpause();
    assert(!contract.paused(), 'Should be unpaused');

    // Test access control
    let role = 1234;
    let account = starknet::contract_address_const::<0x2>();
    assert(!contract.has_role(role, account), 'Should not have role initially');
    contract.grant_role(role, account);
    assert(contract.has_role(role, account), 'Should have role');
    contract.revoke_role(role, account);
    assert(!contract.has_role(role, account), 'Should not have role');
}
