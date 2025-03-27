use starknet::ContractAddress;

#[starknet::component]
mod SecurityComponent {
    use starknet::{ContractAddress, get_caller_address};
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _paused: bool,
        _roles: starknet::storage::Map<(felt252, ContractAddress), bool>,
        _reentrancy_guard: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
        Paused: Paused,
        Unpaused: Unpaused,
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {
        account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct RoleGranted {
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct RoleRevoked {
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress,
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self._owner.write(owner);
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let owner = self._owner.read();
            let caller = get_caller_address();
            assert(caller == owner, 'Caller is not the owner');
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self._paused.read(), 'Contract is paused');
        }

        fn assert_not_entered(ref self: ComponentState<TContractState>) {
            assert(!self._reentrancy_guard.read(), 'Reentrant call');
            self._reentrancy_guard.write(true);
        }

        fn end_call(ref self: ComponentState<TContractState>) {
            self._reentrancy_guard.write(false);
        }
    }

    #[external(v0)]
    impl SecurityComponent of super::IComponents<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self._owner.read()
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self.assert_only_owner();
            let previous_owner = self._owner.read();
            self._owner.write(new_owner);
            self.emit(OwnershipTransferred { previous_owner, new_owner });
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            let previous_owner = self._owner.read();
            self._owner.write(Zeroable::zero());
            self.emit(OwnershipTransferred { 
                previous_owner, 
                new_owner: Zeroable::zero() 
            });
        }

        fn paused(self: @ComponentState<TContractState>) -> bool {
            self._paused.read()
        }

        fn pause(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            assert(!self._paused.read(), 'Contract is already paused');
            self._paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }

        fn unpause(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            assert(self._paused.read(), 'Contract is not paused');
            self._paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }

        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self._roles.read((role, account))
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.assert_only_owner();
            self._roles.write((role, account), true);
            self.emit(RoleGranted { 
                role, 
                account, 
                sender: get_caller_address() 
            });
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            self.assert_only_owner();
            self._roles.write((role, account), false);
            self.emit(RoleRevoked { 
                role, 
                account, 
                sender: get_caller_address() 
            });
        }
    }
}
