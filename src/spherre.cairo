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
    use spherre::types::SpherreAdminRoles;
    use starknet::{ContractAddress, get_caller_address};


    // Interface IDs

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

        // Initialize AccessControl and grant DEFAULT_ADMIN_ROLE to owner
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.access_control._grant_role(SpherreAdminRoles::SUPERADMIN, owner)
    }

    // Implement the ISpherre interface
    #[abi(embed_v0)]
    pub impl SpherreImpl of ISpherre<ContractState> {
        fn grant_superadmin_role(ref self: ContractState, account: ContractAddress) {
            self.ownable.assert_only_owner();
            self.access_control._grant_role(SpherreAdminRoles::SUPERADMIN, account);
        }
        fn grant_staff_role(ref self: ContractState, account: ContractAddress) {
            self.assert_only_superadmin();
            self.access_control._grant_role(SpherreAdminRoles::STAFF, account);
        }
        fn revoke_superadmin_role(ref self: ContractState, account: ContractAddress) {
            self.ownable.assert_only_owner();
            self.access_control._revoke_role(SpherreAdminRoles::SUPERADMIN, account);
        }
        fn revoke_staff_role(ref self: ContractState, account: ContractAddress) {
            self.assert_only_superadmin();
            self.access_control._revoke_role(SpherreAdminRoles::SUPERADMIN, account);
        }
        fn has_staff_role(self: @ContractState, account: ContractAddress) -> bool {
            self.access_control.has_role(SpherreAdminRoles::STAFF, account)
        }
        fn has_superadmin_role(self: @ContractState, account: ContractAddress) -> bool {
            self.access_control.has_role(SpherreAdminRoles::SUPERADMIN, account)
        }
        fn pause(ref self: ContractState) {
            self.assert_only_superadmin();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.assert_only_superadmin();
            self.pausable.unpause();
        }
    }


    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn assert_only_staff(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                self.has_staff_role(caller) || self.has_superadmin_role(caller),
                Errors::ERR_NOT_A_STAFF
            )
        }
        fn assert_only_superadmin(self: @ContractState) {
            let caller = get_caller_address();
            assert(self.has_superadmin_role(caller), Errors::ERR_NOT_A_SUPERADMIN)
        }
    }
}
