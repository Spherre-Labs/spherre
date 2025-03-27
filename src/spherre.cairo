use starknet::ContractAddress;
use components::security::SecurityComponent;

#[starknet::contract]
mod Spherre {
    use super::SecurityComponent;

    component!(path: SecurityComponent, storage: security, event: SecurityEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        security: SecurityComponent::Storage,
        // ... other storage variables
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SecurityEvent: SecurityComponent::Event,
        // ... other events
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.security.initializer(owner);
    }

    // Use security features in your functions:
    #[external(v0)]
    fn some_protected_function(ref self: ContractState) {
        self.security.assert_only_owner();
        self.security.assert_not_paused();
        self.security.assert_not_entered();
        // ... function logic
        self.security.end_call();
    }
}

