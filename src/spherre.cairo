#[starknet::contract]
pub mod Spherre {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use spherre::errors::Errors;
    use spherre::interfaces::ispherre::ISpherre;
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event
    }

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    // Implement Ownable mixin
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Implement Pausable mixin
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        // Note: PausableComponent doesn't require an initializer
    }

    // Implement the ISpherre interface
    #[abi(embed_v0)]
    pub impl SpherreImpl of ISpherre<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            self.ownable.owner()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert_only_owner_custom(@self);
            self.ownable.transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            assert_only_owner_custom(@self);
            self.ownable.renounce_ownership();
        }

        // Pausable implementation
        fn is_paused(self: @ContractState) -> bool {
            self.pausable.is_paused()
        }

        fn pause(ref self: ContractState) {
            assert_only_owner_custom(@self);
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            assert_only_owner_custom(@self);
            self.pausable.unpause();
        }
    }

    // Custom helper methods for the contract
    fn assert_only_owner_custom(self: @ContractState) {
        let caller = get_caller_address();
        if caller != self.ownable.owner() {
            // Panic with the full expected error tuple that matches OpenZeppelin v0.18.0 format
            let error_data = array![
                Errors::ERR_NOT_OWNER_SELECTOR,
                Errors::ERR_NOT_OWNER_PADDING,
                Errors::ERR_NOT_OWNER_MESSAGE,
                Errors::ERR_NOT_OWNER_MARKER
            ];
            panic(error_data);
        }
    }
}
