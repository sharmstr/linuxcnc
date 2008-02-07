library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
-- Copyright (C) 2007, Peter C. Wallace, Mesa Electronics
-- http://www.mesanet.com
--
-- This program is is licensed under a disjunctive dual license giving you
-- the choice of one of the two following sets of free software/open source
-- licensing terms:
--
--    * GNU General Public License (GPL), version 2.0 or later
--    * 3-clause BSD License
-- 
--
-- The GNU GPL License:
-- 
--     This program is free software; you can redistribute it and/or modify
--     it under the terms of the GNU General Public License as published by
--     the Free Software Foundation; either version 2 of the License, or
--     (at your option) any later version.
-- 
--     This program is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--     GNU General Public License for more details.
-- 
--     You should have received a copy of the GNU General Public License
--     along with this program; if not, write to the Free Software
--     Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
-- 
-- 
-- The 3-clause BSD License:
-- 
--     Redistribution and use in source and binary forms, with or without
--     modification, are permitted provided that the following conditions
--     are met:
-- 
--         * Redistributions of source code must retain the above copyright
--           notice, this list of conditions and the following disclaimer.
-- 
--         * Redistributions in binary form must reproduce the above
--           copyright notice, this list of conditions and the following
--           disclaimer in the documentation and/or other materials
--           provided with the distribution.
-- 
--         * Neither the name of Mesa Electronics nor the names of its
--           contributors may be used to endorse or promote products
--           derived from this software without specific prior written
--           permission.
-- 
-- 
-- Disclaimer:
-- 
--     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--     COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
--     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
--     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
--     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
--     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--     POSSIBILITY OF SUCH DAMAGE.
-- 

use work.IDROMParms.all;	

entity i43hostmot2 is
	 generic 
	 (
		STEPGENs: integer := 4;
		QCOUNTERS: integer := 4;
		PWMGens: integer := 4;
		SPIs: integer := 0;
		SSIs: integer := 0;
		UARTs: integer := 0;
		PWMRefWidth: integer := 13;	-- PWM resolution is PWMRefWidth-1 bits 
		StepGenTableWidth: integer := 6; -- How many output bits from stepgen
		IDROMType: integer := 2;		
	   SepClocks: boolean := true;
		OneWS: boolean := true;
		I30Pinout: boolean := true;
		I44pinout: boolean := false;
		QCtrOnlyPinout: boolean := false;
		QCtrOnlyPinoutWithIMask: boolean := false;
		SVST8_4Pinout: boolean := false;
		SVST4_4Pinout: boolean := true;
		ConnsWithI30: integer := 1;
		ConnsWithI44: integer := 0;
		UseStepGenPrescaler : boolean := false;
		UseIRQLogic: boolean := true;
		UseWatchDog: boolean := true;
		OffsetToModules: integer := 64;
		OffsetToPinDesc: integer := 512;
		ClockHigh: integer := ClockHigh43;
		ClockLow: integer := ClockLow43;
		BoardNameLow : std_Logic_Vector(31 downto 0) := BoardNameMESA;
		BoardNameHigh : std_Logic_Vector(31 downto 0) := BoardName7I43;
		FPGASize: integer := 200;
		FPGAPins: integer := 144;
		IOPorts: integer := 2;
		IOWidth: integer := 48;
		PortWidth: integer := 24;
		BusWidth: integer := 32;
		AddrWidth: integer := 16;
		InstStride0: integer := 4;
		InstStride1: integer := 16;
		RegStride0: integer := 256;
		RegStride1: integer := 4;
		LEDCount: integer := 8
		);
		
	Port (	CLK : in std_logic;
				LEDS : out std_logic_vector(7 downto 0);
				IOBITS : inout std_logic_vector(47 downto 0);
				EPP_DATABUS : inout std_logic_vector(7 downto 0);
				EPP_DSTROBE : in std_logic;
				EPP_ASTROBE : in std_logic;
				EPP_WAIT : out std_logic;
				EPP_READ : in std_logic;
				RECONFIG : out std_logic;
				PARACONFIG : out std_logic;
				SPICLK : out std_logic;
--				SPIIN : in std_logic;
				SPIOUT : out std_logic;
				SPICS : out std_logic
		 );
end i43hostmot2;

architecture Behavioral of i43hostmot2 is

	
signal afcnt : std_logic_vector(2 downto 0);
signal afilter : std_logic_vector(1 downto 0);
signal dfcnt : std_logic_vector(2 downto 0);
signal dfilter : std_logic_vector(1 downto 0);
signal rfcnt : std_logic_vector(1 downto 0);
signal rfilter : std_logic;
signal waitpipe : std_logic_vector(9 downto 0);
alias waitpipeend: std_logic is waitpipe(9);
signal alatch : std_logic_vector(AddrWidth-1 downto 0); 
signal seladd : std_logic_vector(AddrWidth-1 downto 0);
signal aread : std_logic;
signal awritele : std_logic;
signal wasaddr : std_logic;
signal dread : std_logic;
signal dreadle : std_logic;
signal dreadte : std_logic;
signal dwritele : std_logic; 
signal dwritete : std_logic; 
signal dstrobete : std_logic; 
signal astrobete : std_logic; 
signal depp_dstrobe : std_logic;
signal depp_astrobe : std_logic;
signal depp_read : std_logic;

signal wdlatch : std_logic_vector(31 downto 0);
signal rdlatch : std_logic_vector(31 downto 0);
signal obus : std_logic_vector(31 downto 0);
signal translateaddr : std_logic_vector(AddrWidth-1 downto 0);
alias  translatestrobe : std_logic is  translateaddr(AddrWidth-1);
signal loadtranslateram : std_logic;
signal readtranslateram : std_logic;
signal translateramsel : std_logic;

signal read32 : std_logic;
signal write32 : std_logic;

signal ReconfigSel : std_logic;
signal idata: std_logic_vector(7 downto 0);

signal ReConfigreg : std_logic := '0';

signal fclk : std_logic;
signal clkfx: std_logic;
signal clk0: std_logic;

begin

ahostmot2: entity HostMot2
	generic map (
		stepgens  => STEPGENs,
		qcounters  => QCOUNTERS,
		pwmgens  => PWMGens,
		spis  => SPIs,
		ssis  => SSIs,
		uarts  => UARTs,
		pwmrefwidth  => PWMRefWidth,
		stepgentablewidth  => StepGenTableWidth,
		idromtype  => IDROMType,		
	   sepclocks  => SepClocks,
		onews  => OneWS,
		i30pinout  => I30Pinout,
		i44pinout  => I44pinout,
		qctronlypinout  => QCtrOnlyPinout,
		qctronlypinoutwithimask  => QCtrOnlyPinoutWithIMask,
		svst8_4pinout => SVST8_4Pinout,
		svst4_4pinout => SVST4_4Pinout,
		connswithi30  => ConnsWithI30,
		connswithi44  => ConnsWithI44,
		usestepgenprescaler => UseStepGenPrescaler,
		useirqlogic  => UseIRQLogic,
		usewatchdog  => UseWatchDog,
		offsettomodules  => OffsetToModules,
		offsettopindesc  => OffsetToPinDesc,
		clockhigh  => ClockHigh,
		clocklow  => ClockLow,
		boardnamelow => BoardNameLow,
		boardnamehigh => BoardNameHigh,
		fpgasize  => FPGASize,
		fpgapins  => FPGAPins,
		ioports  => IOPorts,
		iowidth  => IOWidth,
		portwidth  => PortWidth,
		buswidth  => BusWidth,
		addrwidth  => AddrWidth,
		inststride0 => InstStride0,
		inststride1 => InstStride1,
		regstride0 => RegStride0,
		regstride1 => RegStride1,
		ledcount  => LEDCount
		)
	port map (
		ibus =>  wdlatch,
		obus => obus,
		addr => seladd(AddrWidth-1 downto 2),
		read => read32,
		write => write32,
		clklow => CLK,
		clkhigh =>  fclk,
--		int => INT, 
		iobits => IOBITS,			
		leds => LEDS	
		);

	transmogrifier: entity atrans 
	generic map (
				width => AddrWidth,
				depth =>  8)
	port map(
 		clk => CLK,
		wea => loadtranslateram,
		rea => readtranslateram,
		reb => '1',
 		adda => alatch(9 downto 2),
		addb => alatch(7 downto 0),
 		din => wdlatch(15 downto 0),
 		douta => obus(15 downto 0),
		doutb => translateaddr
		);	
		
   ClockMult : DCM
   generic map (
      CLKDV_DIVIDE => 2.0,
      CLKFX_DIVIDE => 2, 
      CLKFX_MULTIPLY => 4,			-- 4 FOR 100 MHz
      CLKIN_DIVIDE_BY_2 => FALSE, 
      CLKIN_PERIOD => 20.0,          
      CLKOUT_PHASE_SHIFT => "NONE", 
      CLK_FEEDBACK => "1X",         
      DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", 
                                            
      DFS_FREQUENCY_MODE => "LOW",
      DLL_FREQUENCY_MODE => "LOW",
      DUTY_CYCLE_CORRECTION => TRUE,
      FACTORY_JF => X"C080",
      PHASE_SHIFT => 0, 
      STARTUP_WAIT => FALSE)
   port map (
 
      CLK0 => clk0,   	-- 
      CLKFB => clk0,  	-- DCM clock feedback
		CLKFX => clkfx,
      CLKIN => CLK,    -- Clock input (from IBUFG, BUFG or DCM)
      PSCLK => '0',   	-- Dynamic phase adjust clock input
      PSEN => '0',     	-- Dynamic phase adjust enable input
      PSINCDEC => '0', 	-- Dynamic phase adjust increment/decrement
      RST => '0'        -- DCM asynchronous reset input
   );
  
  BUFG_inst : BUFG
   port map (
      O => fclk,    -- Clock buffer output
      I => clkfx      -- Clock buffer input
   );

  -- End of DCM_inst instantiation

	EPPInterface: process(clk, waitpipe, alatch, afilter, dfilter,  
								 EPP_READ, EPP_DSTROBE, EPP_ASTROBE,
								 depp_dstrobe, depp_astrobe)
	begin

		if rising_edge(CLK) then
			depp_dstrobe <= EPP_DSTROBE;			-- async so one level of FF before anything else
			depp_astrobe <= EPP_ASTROBE;
			depp_read <= EPP_READ;
			afilter(1) <= afilter(0);
			dfilter(1) <= dfilter(0);
			if (depp_dstrobe = '0') or (depp_astrobe = '0') then
				waitpipe <= waitpipe(8 downto 0) & '1'; -- left shift in a 1
			else
				waitpipe <= (others => '0');
			end if;	

			if  depp_astrobe = '0' then
				if afcnt /= "111" then 
					afcnt <= afcnt +1;
				end if;
			else
				if afcnt /= "000" then 
					afcnt <= afcnt -1;
				end if;
			end if;
			if afcnt = "111" then	 
				afilter(0) <= '1';
			end if;
			if afcnt = "000" then 
				afilter(0) <= '0';
			end if;

			if  depp_dstrobe = '0' then
				if dfcnt /= "111" then 
					dfcnt <= dfcnt +1;
				end if;
			else
				if dfcnt /= "000" then 
					dfcnt <= dfcnt -1;
				end if;
			end if;
			if dfcnt = "111" then	 
				dfilter(0) <= '1';
			end if;
			if dfcnt = "000" then 
				dfilter(0) <= '0';
			end if;

			if  depp_read = '1' then
				if rfcnt /= "11" then 
					rfcnt <= rfcnt +1;
				end if;
			else
				if rfcnt /= "00" then 
					rfcnt <= rfcnt -1;
				end if;
			end if;
			if rfcnt = "11" then	 
				rfilter <= '1';
			end if;
			if rfcnt = "00" then 
				rfilter <= '0';
			end if;
				
			if awritele = '1' then 
				if wasaddr = '0' then
					alatch(7 downto 0) <= EPP_DATABUS;
				else
					alatch(15 downto 8) <= EPP_DATABUS;
				end if;
			end if;
			
			if dstrobete = '1' then
				wasaddr <= '0';
			end if;

			if astrobete = '1' then
				wasaddr <= '1';
			end if;
					
			if dstrobete = '1' and alatch(15) = '1' then	-- auto increment address on data access if address MSB is 1
				alatch(14 downto 0) <= alatch(14 downto 0) +1;
			end if;	
			
		end if; -- clk	
		
		EPP_WAIT <= waitpipeend;
		
		if dfilter = "01" and rfilter = '0' then	  -- generate write 80 ns after leading edge of strobe
			dwritele <= '1';
		else
			dwritele <= '0';
		end if;

		if dfilter = "10" and rfilter = '0' then	  -- generate write 80 ns after leading edge of strobe
			dwritete <= '1';
		else
			dwritete <= '0';
		end if;

		if dfilter = "01" and rfilter = '1' then	  -- generate read 80 ns after leading edge of strobe
			dreadle <= '1';
		else
			dreadle <= '0';
		end if;

		if dfilter = "10" and rfilter = '1' then	  -- generate read 80 ns after leading edge of strobe
			dreadte <= '1';
		else
			dreadte <= '0';
		end if;

		if dfilter = "10" then								-- generate writete 80 ns after trailng edge of strobe
			dstrobete <= '1';
		else
			dstrobete <= '0';
		end if;

		if afilter = "10" then								-- generate writete 80 ns after trailng edge of strobe
			astrobete <= '1';
		else
			astrobete <= '0';
		end if;

		if afilter = "01" and rfilter  = '0' then	-- generate write 80 ns after leading edge of strobe
			awritele <= '1';
		else
			awritele <= '0';
		end if;
		
		if rfilter = '1' and depp_dstrobe = '0' then
			dread <= '1';
		else
			dread <= '0';
		end if;
		
		if rfilter = '1' and depp_astrobe = '0' then
			aread <= '1';
		else
			aread <= '0';
		end if;		
		
	end process EPPInterface;

	bus_shim32: process (CLK,alatch,EPP_DATABUS) -- 8 to 32 bit bus shim
	begin
		if rising_edge(CLK) then
			if dwritele = '1' then				-- on writes, latch the data in our 32 bit write data latch
				case seladd(1 downto 0) is		-- 32 data is written after last byte saved in latch
					when "00" =>  wdlatch(7 downto 0)   <= EPP_DataBus;
					when "01" =>  wdlatch(15 downto 8)  <= EPP_DataBus;
					when "10" =>  wdlatch(23 downto 16) <= EPP_DataBus;
					when "11" =>  wdlatch(31 downto 24) <= EPP_DataBus;
					when others => null;
				end case;	
			end if;	
			if alatch(14 downto 9) = TranslateRegionAddr(6 downto 1) then
				if dreadle = '1' and translatestrobe = '1' then
					rdlatch <= obus;
				end if;		
			else
				if dreadle = '1' and seladd(1 downto 0) = "00" then
					rdlatch <= obus;
				end if;
			end if;
		end if; -- clk
				
		case seladd(1 downto 0) is								-- on reads, data previously stored in read data latch
			when "00" => idata <= rdlatch(7 downto 0); 	-- is muxed onto 8 bit bus by A(0..1)
			when "01" => idata <= rdlatch(15 downto 8);
			when "10" => idata <= rdlatch(23 downto 16);
			when "11" => idata <= rdlatch(31 downto 24);
			when others => null;
		end case;	
		
		if alatch(14 downto 10) = TranslateRamAddr(6 downto 2) then
			translateramsel <= '1';
		else
			translateramsel <= '0';
		end if;
		
		if dwritete = '1' and translateramsel = '1' then
			loadtranslateram <= '1';
		else
			loadtranslateram <= '0';
		end if;	
			
		if dreadle = '1' and translateramsel = '1' then
			readtranslateram <= '1';
		else
			readtranslateram <= '0';
		end if;

		if alatch(14 downto 8) = TranslateRegionAddr(6 downto 0) then
			write32 <= dwritete and translatestrobe;
			read32 <= dreadle and translatestrobe;
			seladd <= '0'&translateaddr(AddrWidth-2 downto 0);	-- drop msb = translatestrobe
		else
			write32 <= dwritete and alatch(1) and alatch(0);
			read32 <= dreadle and ((not alatch(1)) and (not alatch(0)));
			seladd <= '0'&alatch(AddrWidth-2 downto 0);	-- drop msb = autoincbit
		end if;
	end process;
	
	doreconfig: process (CLK,ReConfigreg)
	begin
		if alatch = x"7F7F" then
			ReconfigSel <= '1';
		else
			ReconfigSel <= '0';		
		end if;	
		if rising_edge(CLK) then
			if dwritele = '1' and ReconfigSel = '1' then
				if EPP_DATABUS = x"5A" then
					ReConfigreg <= '1';
				end if;
			end if;
		end if;		
		RECONFIG <= not ReConfigreg;
	end process doreconfig;
	
	BusDrive: process (aread,dread,idata,alatch)
	begin
		EPP_DATABUS <= "ZZZZZZZZ";
		if dread = '1' then 
			EPP_DATABUS <= idata;
		end if;
		if aread = '1' then 
			if wasaddr = '0' then
				EPP_DATABUS <= alatch(7 downto 0);
			else
				EPP_DATABUS <= alatch(15 downto 8);
			end if;	
		end if;
		PARACONFIG <= '1';
		SPICS <= '1';
		SPICLK <= '0';
		SPIOUT <= '0';
	end process BusDrive;	

end;