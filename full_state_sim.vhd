----------------------------------------------------------------------------------
-- Company: University of Sheffield
-- Engineer: Jordan Fisher
-- 
-- Create Date: 28.04.2020 16:15:00
-- Design Name: 
-- Module Name: fullStateSimulation
-- Project Name: Ising Spin Model Sim
-- Target Devices: BASYS3
-- Tool Versions: 
-- Description: Performs a simulation of the Ising Spin Model (for ferromagnetism), using a 16 bit array & a Horowitz random number generator.
-- 
-- Current value of x used to calcualed probabilities is: 0.5
-- Revision: 2.1
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fullStateSimulation is
    Generic(buttonMaxCount : integer := 22;
            genMaxCount1 : integer := 15;
            genMaxCount2 : integer  := 7);
    Port ( clk : in STD_LOGIC;
           btnC : in STD_LOGIC;
           led : out STD_LOGIC_VECTOR(15 downto 0));
end fullStateSimulation;

architecture Behavioral of fullStateSimulation is
    --counters:
    signal buttonCount_reg, buttonCount_next : UNSIGNED(buttonMaxCount-1 downto 0);
    signal genCounter1_reg, genCounter1_next : UNSIGNED(3 downto 0) := "0000"; --counts up to 15 (but gets stopped at 15, or 16 iterations)
    signal genCounter2_reg, genCounter2_next : UNSIGNED(2 downto 0) := "000"; --counts up to 7 (gets stopped at 7, or 8 iterations)
--    signal tempStoreCounter_reg, tempStoreCounter_next : UNSIGNED(0 downto 0) := "0"; --flicks between 1 & 0, used for indexing the tempStore register
    --storage registers:
    signal output_reg, output_next : STD_LOGIC := '0'; --debounced button output
    signal shift_reg, shift_next : STD_LOGIC_VECTOR(30 downto 0) := "0110100101011010001110100101101"; --random number shift register
    signal spinStates_reg, spinStates_next : STD_LOGIC_VECTOR(15 downto 0); --stores the state of 16 spins
    signal tempStore_reg, tempStore_next : STD_LOGIC_VECTOR(15 downto 0); --stores up to 2 new values of the array of spins
    --state machines:
    type buttonStateType is (pressed, waiting);
    signal buttonState_reg, buttonState_next : buttonStateType := waiting;
    type genStateType is (populate, buttonWait, throw, calculate);
    signal genState_reg, genState_next : genStateType := populate;
begin

process(clk, buttonCount_next, output_next, buttonState_next, genState_next, shift_next, tempStore_next, genCounter1_next, genCounter2_next, spinStates_next)
begin
    if(clk'event and clk='1') then
        --counters:
        buttonCount_reg <= buttonCount_next;
        genCounter1_reg <= genCounter1_next;
        genCounter2_reg <= genCounter2_next;
        --signals
        output_reg <= output_next;
        spinStates_reg <= spinStates_next;
        tempStore_reg <= tempStore_next;
        --state machines
        buttonState_reg <= buttonState_next;
        genState_reg <= genState_next;
        --shift register
        shift_reg <= shift_next;
    end if;
end process;

--DEBOUNCING BUTTON:
buttonState_next <= pressed when (buttonState_reg = waiting and btnC = '1' and buttonCount_reg = to_unsigned(0,buttonMaxCount) ) else
                    waiting when (buttonState_reg = pressed and btnC = '0' and buttonCount_reg = to_unsigned(0,buttonMaxCount) ) else
                    buttonState_reg;
--state machine is above - it only switches from waiting when the button is pressed, and the count is at 0.
--It switches to waiting when the button is not pressed and the count is zero.

--This means that the state can only switch after the dead time (time it takes counter to count 22 bits). 
--This ensures any button input other than the wanted single press isn't detected.

--i.e., after the count up to 22 bits, the state will move back to waiting. (if the button is still not pressed)

buttonCount_next <= buttonCount_reg + 1 when ( (btnC = '1' and buttonState_reg = waiting) or (btnC = '0' and buttonState_reg = pressed) or (buttonCount_reg > to_unsigned(0,buttonMaxCount) ) ) else
                    to_unsigned(0,buttonMaxCount);
--count only increases when 1 of these conditions are filled:
--button is pressed and state is waiting
--button is not pressed and state is pressed
--count is above zero

--Otherwise, the counter resets to zero & does nothing else.

--i.e, when there is a wanted transition (button is pressed) between states, the counter starts counting.
--According to the state machine, it cannot transition until the counter is zero - so the counter has to count until it either overflows,
--or stops detecting an input from the button, eliminating extra unintended button pushes.

output_next <= '1' when (btnC = '1' and buttonState_reg = waiting and buttonCount_reg = to_unsigned(0,buttonMaxCount) ) else
               '0';
--output value only changes when all 3 conditions are filled:
--button is pressed
--state is waiting
--count is zero

--MAIN STATE MACHINE:

process(genState_reg, output_reg, genCounter1_reg, genCounter2_reg, tempStore_reg, shift_reg, spinStates_reg)
begin
    case genState_reg is
        when populate => --initial state: generate 16 random numbers, and initialise the spin registers
            spinStates_next <= spinStates_reg;
            
            
            --RANDOM NUMBER GEN:
            shift_next(0) <= shift_reg(27) xnor shift_reg(30);
            shift_next(30 downto 1) <= shift_reg(29 downto 0);
            --the input of the shift registers is the XNOR logic of bit 27 and bit 30
            --Every clock cycle, the value of 1 bit gets copied up to the next bit
                    
            if (genCounter1_reg = genMaxCount1) then
                genState_next <= buttonWait;
                genCounter1_next <= to_unsigned(0,4);
                spinStates_next <= shift_reg(15 downto 0);
                --if counter has counted 16 times, update spin values with the random numbers & move to wait button state
            else
                genCounter1_next <= genCounter1_reg + 1;
                genState_next <= populate;
            end if;
        when buttonWait => --waits for a debounced button output
            --BELOW: Saving states of signals
            spinStates_next <= spinStates_reg;
            tempStore_next <= tempStore_reg;
            genCounter1_next <= genCounter1_reg;
            
            if (output_reg = '1') then
                genCounter1_next <= to_unsigned(0,4);
                genCounter2_next <= to_unsigned(0,3);
                genState_next <= throw;
            else
                genState_next <= buttonWait;
            end if;
        when throw =>
            spinStates_next <= spinStates_reg;
            tempStore_next <= tempStore_reg;
            genCounter1_next <= genCounter1_reg;
            
            --RANDOM NUMBER GEN:
            shift_next(0) <= shift_reg(27) xnor shift_reg(30);
            shift_next(30 downto 1) <= shift_reg(29 downto 0);
            --the input of the shift registers is the XNOR logic of bit 27 and bit 30
            --Every clock cycle, the value of 1 bit gets copied up to the next bit
            
            if (genCounter2_reg = genMaxCount2) then
                genState_next <= calculate;
                genCounter2_next <= to_unsigned(0,3);
                --if counter has counted 8 times, move to calculate state with new 8 bit random number
            else
                genCounter2_next <= genCounter2_reg + 1;
                genState_next <= throw;
                
            end if;
        when calculate =>
            shift_next <= shift_reg;
            --(above) Keep values from previous iterations
            
            if (spinStates_reg(to_integer(genCounter1_reg-1)) = '1' and spinStates_reg(to_integer(genCounter1_reg+1)) = '1') then --neighbours aligned UP
                if ( UNSIGNED(shift_reg(7 downto 0) ) < to_unsigned(10#186#,8) ) then
                    tempStore_next( to_integer(genCounter1_reg) ) <= '1'; --UP
                elsif ( UNSIGNED(shift_reg(7 downto 0) ) >= to_unsigned(10#186#,8) ) then
                    tempStore_next( to_integer(genCounter1_reg) ) <= '0'; --DOWN
--                spinStates_next(to_integer(genCounter1_reg - 1)) <= tempStore_reg(to_integer(tempStoreCounter_reg - 1) ); --UPDATE LEFT NEIGHBOUR
                end if; --(above) IF neighbours aligned UP, then UP is more likely than DOWN, because UP is the ground state (lower energy).
                
            elsif (spinStates_reg(to_integer(genCounter1_reg-1)) = '0' and spinStates_reg(to_integer(genCounter1_reg+1)) = '0') then --neighbours aligned DOWN
                if ( UNSIGNED(shift_reg(7 downto 0) ) < to_unsigned(10#186#,8) ) then
                    tempStore_next( to_integer(genCounter1_reg) ) <= '0'; --DOWN
                elsif ( UNSIGNED(shift_reg(7 downto 0) ) >= to_unsigned(10#186#,8) ) then
                    tempStore_next( to_integer(genCounter1_reg ) ) <= '1'; --UP
                end if; --(above) IF neighbours aligned DOWN, then DOWN is more likely than UP, because DOWN is the ground state (lower energy).
                
            elsif( ( spinStates_reg(to_integer(genCounter1_reg-1) ) = '0' and spinStates_reg(to_integer(genCounter1_reg+1) ) = '1' ) or ( spinStates_reg(to_integer(genCounter1_reg-1) ) = '1' and spinStates_reg(to_integer(genCounter1_reg+1) ) = '0') ) then --neighbours anti-aligned
                if ( UNSIGNED(shift_reg(7 downto 0) ) >= to_unsigned(10#127#,8) ) then
                    tempStore_next( to_integer(genCounter1_reg) ) <= '1'; --UP
                elsif ( UNSIGNED(shift_reg(7 downto 0) ) < to_unsigned(10#127#,8) ) then
                    tempStore_next( to_integer(genCounter1_reg) ) <= '0'; --DOWN
--                spinStates_next(to_integer(genCounter1_reg - 1)) <= tempStore_reg(to_integer(tempStoreCounter_reg - 1) ); --UPDATE LEFT NEIGHBOUR
                end if;
                --(above) IF neighbours anti-aligned, decide on new positions based on random number & save them in the temp array, whilst updating spin array with last iteration values
            end if;
            if (genCounter1_reg = genMaxCount1) then
                genState_next <= buttonWait;
                genCounter1_next <= to_unsigned(0,4);
                spinStates_next <= spinStates_reg;
            else
                genState_next <= throw;
                genCounter2_next <= to_unsigned(0,3);
                genCounter1_next <= genCounter1_reg + 1;
                spinStates_next <= tempStore_reg;
            end if;
    end case;
end process;

led <= spinStates_reg;

end Behavioral;