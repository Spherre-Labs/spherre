#[starknet::component]
pub mod PermissionControl {
    // Adjust these import paths as needed.
    use spherre::types::Permissions;
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};

    // Storage for permissions: mapping from (permission, member) to bool.
    #[storage]
    pub struct Storage {
        member_permission: Map<(felt252, ContractAddress), bool>,
    }

    // Events emitted by this component.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PermissionGranted: PermissionGranted,
        PermissionRevoked: PermissionRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionGranted {
        pub permission: felt252,
        pub member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionRevoked {
        pub permission: felt252,
        pub account: ContractAddress,
    }

    // -------------------------------
    // External interface implementation.
    // The first generic parameter MUST be TContractState.
    #[embeddable_as(PermissionControl)]
    impl PermissionControlImpl<TContractState, +HasComponent<TContractState>>
        of IPermissionControl<ComponentState<TContractState>>
    {
        /// Checks if the given member has the specified permission.
        /// Returns true if the member has the permission, false otherwise.
        fn has_permission(
            self: @ComponentState<TContractState>,
            member: ContractAddress,
            permission: felt252
        ) -> bool {
            self.member_permission.entry((permission, member)).read()
        }
        
    }

    #[generate_trait]
    impl PermissionControlInternalImpl<TContractState, +HasComponent<TContractState>>
        of PermissionControlInternalTrait<TContractState>
    {
        /// Assigns the proposer permission to a member.
        /// Emits a PermissionGranted event.
        fn assign_proposer_permission(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress
        ) {
            self.member_permission.write((Permissions::PROPOSER, member), true);
            self.emit(Event::PermissionGranted(PermissionGranted { permission: Permissions::PROPOSER, member }));
        }
    
        /// Assigns the voter permission to a member.
        /// Emits a PermissionGranted event.
        fn assign_voter_permission(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress
        ) {
            self.member_permission.write((Permissions::VOTER, member), true);
            self.emit(Event::PermissionGranted(PermissionGranted { permission: Permissions::VOTER, member }));
        }
    
        /// Assigns the executor permission to a member.
        /// Emits a PermissionGranted event.
        fn assign_executor_permission(
            ref self: ComponentState<TContractState>, 
            member: ContractAddress
        ) {
            self.member_permission.write((Permissions::EXECUTOR, member), true);
            self.emit(Event::PermissionGranted(PermissionGranted { permission: Permissions::EXECUTOR, member }));
        }
    }
}
