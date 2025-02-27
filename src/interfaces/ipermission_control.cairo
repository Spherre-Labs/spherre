use starknet::ContractAddress;

pub const IACCESSCONTROL_ID: felt252 =
    0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751;

#[starknet::interface]
pub trait IAccessControl<TState> {
    fn has_permission(self: @TState, permission: felt252, member: ContractAddress) -> bool;
    fn get_permission_admin(self: @TState, role: felt252) -> felt252;
    // fn grant_role(ref self: TState, role: felt252, account: ContractAddress);
    fn revoke_permission(ref self: TState, permission: felt252, member: ContractAddress);
    // fn renounce_role(ref self: TState, role: felt252, account: ContractAddress);
}