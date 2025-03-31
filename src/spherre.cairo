#[starknet::contract]
pub mod Spherre {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use spherre::errors::Errors;
    use spherre::interfaces::ispherre::ISpherre;
    use starknet::{ContractAddress, get_caller_address};

    // Roles
    const PROPOSER_ROLE: felt252 = 'PR';
    const EXECUTOR_ROLE: felt252 = 'ER';
    const VOTER_ROLE: felt252 = 'VR';

    // Interface IDs
    const IACCESS_CONTROL_ID: felt252 =
        0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
    );
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Implement Ownable mixin
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Implement Pausable mixin
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    // Implement ReentrancyGuard mixin (only has InternalImpl)
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    // Implement AccessControl mixin
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // Implement SRC5 mixin
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize Ownable
        self.ownable.initializer(owner);
        // Note: PausableComponent doesn't require an initializer
        // Note: ReentrancyGuardComponent doesn't require an initializer

        // Register interfaces with SRC5
        self.src5.register_interface(IACCESS_CONTROL_ID);

        // Initialize AccessControl and grant DEFAULT_ADMIN_ROLE to owner
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, owner);
        // Register interfaces with SRC5
    // Note: SRC5 doesn't have an initializer method
    // Instead, register the interfaces you support
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

        // ReentrancyGuard implementation
        fn reentrancy_guard_start(ref self: ContractState) {
            self.reentrancy_guard.start();
        }

        fn reentrancy_guard_end(ref self: ContractState) {
            self.reentrancy_guard.end();
        }

        // AccessControl implementation
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            self.access_control.has_role(role, account)
        }

        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            self.access_control.get_role_admin(role)
        }

        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            // Use the custom owner check to ensure consistent error messages
            assert_only_owner_custom(@self);
            self.access_control.grant_role(role, account);
        }

        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            // Use the custom owner check to ensure consistent error messages
            assert_only_owner_custom(@self);
            self.access_control.revoke_role(role, account);
        }

        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            // Make sure the caller is the account that is renouncing the role
            let caller = get_caller_address();
            assert(caller == account, Errors::INVALID_CALLER);
            self.access_control.renounce_role(role, account);
        }

        // SRC5 implementation
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            self.src5.supports_interface(interface_id)
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
