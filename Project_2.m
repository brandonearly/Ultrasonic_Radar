%%Program Name: Project 2
%%Program Description: Ultrasonic Radar using ultrasonic sensor and a servo
%%motor
%%Date of Creation: 10-26-2025

%%Name: Brandon Early

%clear variables, command windown, etc.
clear %%clears workspace
clc %%clears command window
close all %%closes all figures

% Connect to Arduino and setup
a = arduino('COM4', 'Uno', 'Libraries', {'Servo', 'Ultrasonic'});
s = servo(a, 'D4');
u = ultrasonic(a, 'D2', 'D3');
angles = [];
distances = [];
times = [];
timeStart = tic;

%setting up the 'radar' plot    
figure('Visible', 'on', 'WindowStyle', 'normal');
graph = polaraxes; %polar plot, this means no x/y axes just r and theta
rlim([0 1]); %capping the measurements at 1 meter, can be expanded but idk how good this ultrasonic sensor is
thetalim([0 180]); %capping the angles at 180 for the servo
graph.ThetaZeroLocation = 'right'; %preference
graph.ThetaDir = 'counterclockwise'; %adjust based on zero location

%make it look pretty, RGB codes
graph.Color = 'k';
graph.GridColor = [0 1 0]; 
graph.RColor = [0 1 0];
graph.ThetaColor = [0 1 0];
hold on;

%rest of the housekeeping
pointsFar = polarplot(graph, 0, 0, 'g.', 'MarkerSize', 10); %plotting them seperately so that I can change the color of the points easily
pointsClose = polarplot(graph, 0, 0, 'r.', 'MarkerSize', 10);

count = 0; %our estimated people/objects in view variable
last_angle_count = -Inf; %the 30 degree buffer for new counts 

scan = polarplot(graph, 0, 0, 'Color', [0 1 0], 'LineWidth', 2); % sweeping line visual
title('Ultrasonic Radar');
hold on;

x = 1; %for one full 180 degree sweep both ccw and then back cw, remove and add while(true) for a non-stopping version

while(x > 0)

    % Sweep servo from 0 to 180 degrees
    for(angle = 0:3:180)

        %moving the servo
        writePosition(s, angle / 180);  %servo position input is range of 0–1
        pause(0.05); %for smoother movement/no race condition scenarios with the sensors measurments and my vectors
        
        %take distance measurement
        dist = readDistance(u);
        dist = min(dist, 1); %% max range of 1m, adjust as needed with sensor capabilites

        %if distance is within threshold, turn on the LED/Buzzer
        if(dist < .25)
            a.writeDigitalPin("D12", 1);
        else
            a.writeDigitalPin("D12", 0);
        end

        %appending measurements to the data collection arrays, could have
        %the size of these preallocated to save computation time but I want
        %to leave it to allow for the while(true) implementation to work. 
        angles = [angles; deg2rad(angle)];
        distances = [distances; dist];
        times = [times; toc(timeStart)];
        
        %check recency of measurements to avoid plot clutter after a while
        % VALUES ARE STILL IN ARRAY EVEN ONCE GONE FROM PLOT
        %The tic/toc part of this variable is only relevant for the
        %while(true) variation, would also have to add: '-times) <= 5' or
        %whatever the desired time threshold is
        recent = (toc(timeStart));

        %check distance measurement to see if within 'close' threshold for
        %plot coloring
        %(arbitrary but im setting baseline at .25 meters)
        close = recent & (distances < .25);
        far = recent & (distances >= .25);

        %plotting data
        set(pointsFar, 'ThetaData', angles(far), 'RData', distances(far));
        set(pointsClose, 'ThetaData', angles(close), 'RData', distances(close));
        set(scan, 'ThetaData', [deg2rad(angle), deg2rad(angle)], 'RData', [0 1]); %updating the radar line, polarplot expects 2d vectors
        drawnow; %this allows for live updating rather than waiting for the program to run then displaying the plot
    end

    % Back the other way, all of this code is essentially identical to
    % above
    for(angle = 180:-3:0)

        writePosition(s,angle/180);
        pause(0.05);

        dist = readDistance(u);
        dist = min(dist, 1);

        if(dist < .25)
            a.writeDigitalPin("D12", 1);
        else
            a.writeDigitalPin("D12", 0);
        end

        angles = [angles; deg2rad(angle)];
        distances = [distances;dist];
        times = [times; toc(timeStart)];
        
        recent = (toc(timeStart));

        close = recent & (distances < .25);
        far = recent & (distances >= .25);
    
        set(pointsFar, 'ThetaData', angles(far), 'RData', distances(far));
        set(pointsClose, 'ThetaData', angles(close), 'RData', distances(close));
        set(scan, 'ThetaData', [deg2rad(angle), deg2rad(angle)], 'RData', [0 1]);
        drawnow;
    end
    x = x -1; %for the one loop variation, insures no infinite loop/runtime errors
end

% Calculate and display average distance and median distance
avgDistance = round(mean(distances) * 100);
medianDistance = round(median(distances) * 100);
fprintf("Median Distance of Points: %.2f cm\n", medianDistance);
fprintf("Average Distance of Points: %.2f cm", avgDistance);

%count/predicted people logic
for(i = 1:length(distances))
    if(distances(i) < .25 && abs(angles(i) - last_angle_count) > deg2rad(30))
        count = count +1;
        last_angle_count = angles(i);
    end
end

count = count / 2; %%because we 'sweep' back the other direction, it will almost always count the same object twice
fprintf("Estimated Number of People in the Area: %.0f ", count);

%just to turn off the buzzer cause its annoying if it runs forever
writeDigitalPin(a, "D12", 0);