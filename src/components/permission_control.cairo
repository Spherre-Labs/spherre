#[starknet::component]
pub mod PermissionControl {
    use starknet::ContractAddress;
    use starknet::storage::Map;
    use spherre::types::permissions; // Import permission constants
    use spherre::interfaces::ipermission_control; // Import the interface

        #[storage]
        pub struct Storage {
            member_permission: Map<(felt252, ContractAddress), bool>
        }
    
        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            PermissionGranted: PermissionGranted,
        }
    
        #[derive(Drop, starknet::Event)]
        pub struct PermissionGranted {
            pub permission: felt252,
            pub member: ContractAddress
        }
    
        #[derive(Drop, starknet::Event)]
        pub struct PermissionRevoked {
            pub permission: felt252,
            pub account: ContractAddress
        }

    #[embeddable_as(PermissionControl)]
    impl PermissionControlImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ipermission_control::IPermissionControl<ComponentState<TContractState>> {
        fn has_permission(
            self: @ComponentState<TContractState>,
            member: ContractAddress,
            permission: felt252,
        ) -> bool {
            self.member_permission.read((permission, member))
        }

        fn assign_proposer_permission(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
        ) {
            self._assign_permission(permissions::PROPOSER, member);
        }

        fn assign_voter_permission(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
        ) {
            self._assign_permission(permissions::VOTER, member);
        }

        fn assign_executor_permission(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
        ) {
            self._assign_permission(permissions::EXECUTOR, member);
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>,
            new_owner: ContractAddress,
        ) {
            self._assign_permission(permissions::PROPOSER, new_owner);
            self._assign_permission(permissions::VOTER, new_owner);
            self._assign_permission(permissions::EXECUTOR, new_owner);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assign_permission(
            ref self: ComponentState<TContractState>,
            permission: felt252,
            member: ContractAddress,
        ) {
            self.member_permission.write((permission, member), true);
            self.emit(Event::PermissionGranted(PermissionGranted { permission, member }));
        }
    }
}
