describe 'Cmds#stream' do
  describe "streaming to an output file" do
    describe "given a path that does not exist" do
      let( :path ){ Cmds::ROOT / 'tmp' / 'stream_out.txt' }
      
      before :each do
        FileUtils.rm( path ) if path.exist?
      end
      
      context "using &io_block" do
        context "and passing it the path opened for write" do
          it "should write to the file" do
            Cmds.stream "echo here" do |io|
              io.out = path.open( 'w' )
            end
            
            expect( path.read ).to eq "here\n"
          end
        end
        
        context "and passing it the path string" do
          it "should create the file and write to it" do
            Cmds.stream "echo there" do |io|
              io.out = path.to_s
            end
            
            expect( path.read ).to eq "there\n"
          end
        end
        
        context "and passing it the pathname" do
          it "should create the file and write to it" do
            Cmds.stream "echo everywhere" do |io|
              io.out = path
            end
            
            expect( path.read ).to eq "everywhere\n"
          end
        end
      end # using &io_block
      
      
      # Not sure how to deal with this re capture, so leave it out for now
      # context "using constructor keyword" do
      #   context "and passing it the path opened for write" do
      #     it "should write to the file" do
      #       Cmds.new( "echo here", out: path.open( 'w' ) ).stream
      #       expect( path.read ).to eq "here\n"
      #     end
      #   end
      # 
      #   context "and passing it the path string" do
      #     it "should create the file and write to it" do
      #       Cmds.new( "echo there", out: path.to_s ).stream
      #       expect( path.read ).to eq "there\n"
      #     end
      #   end
      # 
      #   context "and passing it the pathname" do
      #     it "should create the file and write to it" do
      #       Cmds.new( "echo everywhere", out: path ).stream
      #       expect( path.read ).to eq "everywhere\n"
      #     end
      #   end
      # end # using constructor keyword
    end # "given a path that does not exist"
  end # streaming to an output file
  
end # Cmds#stream
