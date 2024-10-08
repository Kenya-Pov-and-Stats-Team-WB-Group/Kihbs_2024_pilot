///Correct the raw household level data 

replace J13=4 if interview__key=="95-87-22-79" 
//and more replacements in the form replace XXX=YYY if interview__key=="ZZZZZZZZ" 
