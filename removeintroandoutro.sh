introlength=80
outrolength=52

for i in *.mp4
do 
	EndOfIntroSeconds=$(bw_plex ffmpeg-process "$i")
	EndOfIntroSecondsCheck=$(bw_plex ffmpeg-process "$i" 2>&1 | grep final_video)
	EndOfIntroSecondsCheckArray=($(echo ${EndOfIntroSecondsCheck/*final_video/} | tr -d "[],'"))
	NumOfElements=${#EndOfIntroSecondsCheckArray[@]}

	for (( idx=${#EndOfIntroSecondsCheckArray[@]}-1 ; idx>=6 ; idx-=3 )) ; do
		# echo ${EndOfIntroSecondsCheckArray[idx]} >> test
		# echo ${EndOfIntroSecondsCheckArray[idx-2]} >> test
		SupposedEndBasedOnVideo=${EndOfIntroSecondsCheckArray[idx-2]}
		SupposedEndBasedOnVideoArray=($(echo $SupposedEndBasedOnVideo | tr ":" "\n"))
		SupposedBeginningBasedOnVideo=${EndOfIntroSecondsCheckArray[idx-5]}
		SupposedBeginningBasedOnVideoArray=($(echo $SupposedBeginningBasedOnVideo | tr ":" "\n"))
		if (( SupposedBeginningBasedOnVideoArray[0] > SupposedEndBasedOnVideoArray[0] ))
		then
				SupposedEndBasedOnVideo=${EndOfIntroSecondsCheckArray[idx-1]}
				SupposedEndBasedOnVideoArray=($(echo $SupposedEndBasedOnVideo | tr ":" "\n"))
		fi
		
		if (( SupposedBeginningBasedOnVideoArray[0] == 0 ));
		then
			SupposedBeginningBasedOnVideo=${EndOfIntroSecondsCheckArray[idx-4]}
			SupposedBeginningBasedOnVideoArray=($(echo $SupposedBeginningBasedOnVideo | tr ":" "\n"))
		fi
		
		SupposedBeginningBasedOnVideoSeconds=$(echo ${SupposedBeginningBasedOnVideoArray[0]}*60+${SupposedBeginningBasedOnVideoArray[1]} | bc -l)
		SupposedEndBasedOnVideoArraySeconds=$(echo ${SupposedEndBasedOnVideoArray[0]}*60+${SupposedEndBasedOnVideoArray[1]} | bc -l)
		
		IntroLengthCheck=$(echo $SupposedEndBasedOnVideoArraySeconds - $SupposedBeginningBasedOnVideoSeconds | bc -l)
		
		#echo $SupposedEndBasedOnVideoArraySeconds - $SupposedBeginningBasedOnVideoSeconds
		#echo $IntroLengthCheck
	
		if (( IntroLengthCheck == introlength+1 )) || (( IntroLengthCheck == introlength )) || (( IntroLengthCheck == introlength-1 )) || (( IntroLengthCheck == introlength-2 ))
		then
			IntegerEndIntroSeconds=$SupposedEndBasedOnVideoArraySeconds
			break
		else
			EndOfIntroSeconds=$(echo "$EndOfIntroSeconds" | bc -l)
			IntegerEndIntroSeconds=$(printf "%.0f\n" $(echo "$EndOfIntroSeconds" | bc -l))
		fi
	done
	
	IntegerBeginIntroSeconds=$IntegerEndIntroSeconds-$introlength
	IntegerBeginIntroSeconds=$(echo "$IntegerBeginIntroSeconds" | bc -l)

	ffmpeg -i "$i" -t $IntegerBeginIntroSeconds -c copy 1.mp4 # -ss 5 to strip the mgm lion but it causes too much loss without reencode.. was causing audio sync problems? or was that the remerge....
	Duration=$(bc <<< $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$i")-$outrolength) # 67 for season 2 60 was fine for season 6
	DurationMod=$(echo $Duration - $IntegerEndIntroSeconds | bc -l)
	ffmpeg -i "$i" -ss $IntegerEndIntroSeconds -t $DurationMod -c copy 2.mp4
	ffmpeg -safe 0 -f concat -i <(printf "file '$PWD/1.mp4'\nfile '$PWD/2.mp4'") -c copy "processed/$i"
	rm -rf 1.mp4 2.mp4
	echo "$i $IntegerBeginIntroSeconds $IntegerEndIntroSeconds - Title Sequence Duration : $IntroLengthCheck" >> intro_convert_record
done