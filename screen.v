module top #(
    parameter STARTUP_WAIT = 32'd10000000,
    parameter DT = 17'b10000000000000000
) (
    input clk,
    input btn1,
    input btn2,
    output o_sclk,
    output o_sdin,
    output o_cs,
    output o_dc,
    output o_reset
);

localparam STATE_INIT_POWER = 0;
localparam STATE_LOAD_DATA = 1;
localparam STATE_SEND = 2;

reg [31:0] spi_counter = 0;
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

always @(posedge clk) begin
    case (state)

        STATE_INIT_POWER: begin
            spi_counter <= spi_counter + 1;
            if (spi_counter < STARTUP_WAIT)
                reset <= 1;
            else if (spi_counter < STARTUP_WAIT * 2)
                reset <= 0;
            else if (spi_counter < STARTUP_WAIT * 3)
                reset <= 1;
            else begin
                state <= STATE_LOAD_DATA;
                spi_counter <= 0;
            end
        end
    
        STATE_LOAD_DATA: begin
            cs <= 0;
            state <= STATE_SEND;
            bitNumber <= 3'b111;
            
            if (commandIndex == 0) begin
                dc <= 1;
                pixelCounter <= pixelCounter + 1;

                if (pixelCounter == (yPos[11:9]<<7) + {3'b0, xPos[12:6]})
                    dataToSend <= (8'b1 << yPos[8:6]) | (paddlePixel<< 7);
                else
                    dataToSend <= (paddlePixel << 7);
            
            end else begin
                dc <= 0;
                dataToSend <= startupCommands[(commandIndex-1)-:8'd8];
                commandIndex <= commandIndex - 8'd8;
            end
        end

        STATE_SEND: begin
            if (spi_counter == 0) begin 
                //Set the line to value
                sdin <= dataToSend[bitNumber];
                sclk <= 0;
                spi_counter <= 1;
            end else begin 
                //Prepare for set, Data read by slave here
                sclk <= 1;
                spi_counter <= 0;
                if (bitNumber == 0)
                    state <= STATE_LOAD_DATA;
                else
                    bitNumber <= bitNumber - 1;
            end
        end

    endcase
end

//Pong
//uses fixed precision arithemetic

reg [12:0] xPos = 13'b1000000000000;
reg [11:0] yPos = 12'b100000000000; // Big Pixel-[100] Pixel pos-[000] precision-[000000]

reg [4:0] xVel = 5'b00101;
reg [4:0] yVel = 5'b00010;

reg xSign = 1;
reg ySign = 0;

localparam PADDLE_LENGTH = 16;
reg [6:0] paddlePos = 7'd64;
wire paddlePixel = (pixelCounter - (128*7 + paddlePos) < PADDLE_LENGTH);

reg [20:0] sim_counter = 0;

reg [2:0] btn1_counter = 0;
reg [2:0] btn2_counter = 0;
localparam BTN_SENSTIVITY = 3'b11; //Higher then value, slower the controls

always @(posedge clk) begin
    sim_counter <= sim_counter + 1;
    if (sim_counter == DT) begin
        sim_counter <= 0;

        if (xSign)
            xPos <= xPos + xVel;
        else
            xPos <= xPos - xVel;
        if (ySign)
            yPos <= yPos + yVel;
        else
            yPos <= yPos - yVel;

        if (xPos[12:6] == 7'b1111111)
            xSign <= 0;
        else if (xPos[12:6] == 7'b0)
            xSign <= 1;
        if (yPos[11:6] == 6'b0)
            ySign <= 1;
        else if (yPos[11:6] == 6'b111111) //bottom of screen
            if (xPos[12:6] - paddlePos < PADDLE_LENGTH) begin
                ySign <= 0;
            end else begin //GAME OVER
                xVel <= 0;
                yVel <= 0; 
            end
        
        //Active low
        btn1_counter <= btn1_counter + ~btn1;
        btn2_counter <= btn2_counter + ~btn2;

        if (~btn1 && (btn1_counter == BTN_SENSTIVITY) && (paddlePos > 0)) begin
            paddlePos <= paddlePos - 1;
        end
        if (~btn2 && (btn2_counter == BTN_SENSTIVITY) && (paddlePos < 127 - PADDLE_LENGTH)) begin
            paddlePos <= paddlePos + 1;
        end

    end
end

endmodule
