module top #(
    parameter STARTUP_WAIT = 32'd10000000
) (
    input clk,
    output o_sclk,
    output o_sdin,
    output o_cs,
    output o_dc,
    output o_reset
);

localparam STATE_INIT_POWER = 0;
localparam STATE_LOAD_DATA = 1;
localparam STATE_SEND = 2;

reg [31:0] counter = 0;
reg [1:0] state = 0;

reg dc = 1;
reg sclk = 1;
reg sdin = 0;
reg reset = 1;
reg cs = 0;

assign o_cs = cs;
assign o_dc = dc;
assign o_sclk = sclk;
assign o_reset = reset;
assign o_sdin = sdin;

reg [7:0] dataToSend;
reg [2:0] bitNumber;  
reg [9:0] pixelCounter = 0;

localparam SETUP_INSTRUCTIONS = 23;
  reg [(SETUP_INSTRUCTIONS*8)-1:0] startupCommands = {
    8'hAE,  // display off

    8'h81,  // contrast value to 0x7F according to datasheet
    8'h7F,  

    8'hA6,  // normal screen mode (not inverted)

    8'h20,  // horizontal addressing mode
    8'h00,  

    8'hC8,  // normal scan direction

    8'h40,  // first line to start scanning from

    8'hA1,  // address 0 is segment 0

    8'hA8,  // mux ratio
    8'h3f,  // 63 (64 -1)

    8'hD3,  // display offset
    8'h00,  // no offset

    8'hD5,  // clock divide ratio
    8'h80,  // set to default ratio/osc frequency

    8'hD9,  // set precharge
    8'h22,  // switch precharge to 0x22 default

    8'hDB,  // vcom deselect level
    8'h20,  // 0x20 

    8'h8D,  // charge pump config
    8'h14,  // enable charge pump

    8'hA4,  // resume RAM content

    8'hAF   // display on
  };
  reg [7:0] commandIndex = SETUP_INSTRUCTIONS * 8;

// reg [7:0] screenBuffer [1023:0];
// initial $readmemh("image.hex", screenBuffer);

always @(posedge clk) begin
    case (state)

        STATE_INIT_POWER: begin
            counter <= counter + 1;
            if (counter < STARTUP_WAIT)
                reset <= 1;
            else if (counter < STARTUP_WAIT * 2)
                reset <= 0;
            else if (counter < STARTUP_WAIT * 3)
                reset <= 1;
            else begin
                state <= STATE_LOAD_DATA;
                counter <= 0;
            end
        end
    
        STATE_LOAD_DATA: begin
            cs <= 0;
            state <= STATE_SEND;
            bitNumber <= 3'b111;
            
            if (commandIndex == 0) begin
                dc <= 1;
                pixelCounter <= pixelCounter + 1;

                if (pixelCounter == (8'b10000000*yPos[9:7]) + {3'b0, xPos[10:4]})
                    dataToSend <= (8'b1 << yPos[6:4]);
                else
                    dataToSend <= 0;
            
            end else begin
                dc <= 0;
                dataToSend <= startupCommands[(commandIndex-1)-:8'd8];
                commandIndex <= commandIndex - 8'd8;
            end
        end

        STATE_SEND: begin
            if (counter == 0) begin 
                //Set the line to value
                sdin <= dataToSend[bitNumber];
                sclk <= 0;
                counter <= 1;
            end else begin 
                //Prepare for set, Data read by slave here
                sclk <= 1;
                counter <= 0;
                if (bitNumber == 0)
                    state <= STATE_LOAD_DATA;
                else
                    bitNumber <= bitNumber - 1;
            end
        end

    endcase
end

//Bouncing Ball Sim
//fixed precision arithemetic

reg [10:0] xPos = 11'b10000000000;
reg [9:0] yPos = 10'b1000000000; // Big Pixel-[100] Pixel pos-[000] precision-[0000]

endmodule
