# Sitecore Docker Starter Kit

## The Dream

This step is a small step towards a bigger dream, of helping the community out with a Starter Kit, to start of Sitecore Projects, with a Single Docker Starterkit.
As an initial step, we have considered only a few modules linked to it, but the final achievement will be to get all those modules which can be considered as must haves, are integrated into the Starterkit, for all the Sitecore Versions, starting 10.1 and as Developers, we just get to pick and choose what to install and what to not. And once the things are chosen, all those things are available to us -- configured and set for all of us to get started on this.

This Dream and now the goal is of two people - [Jatin Prajapati](https://twitter.com/jatin_praj) and [Varun Shringarpure](https://twitter.com/varunvns) who are the initial contributors of this Starterkit. And we welcome anyone to join us in this noble cause, of making the life of any other Sitecore Developer better.

So lets get started!

## Challenge

Well, when Jatin and I started off on a Journey on Sitecore with Container and Docker - right when Sitecore 10.0 was launched, we noticed that there was a huge learning curve, for a Sitecore Developer who starts on to the Container and Docker path. There were things to get started from some front runners of Sitecore team as well as some community members, but, when we looked at actual project implementations, there was still lot of ground to cover.
As both of us were new to a lot of things, spent a lot of hours learning through a number of things and getting through to a place where we felt comfortable with Sitecore running successfully on Docker - whether its XP0 or XP Scaled and hence we thought, of making an effort to reduce this pain, for our dear community members of Sitecore - that in the long run, it is easy for everyone to move ahead and configure their Visual Studio Solution as well as the required configuration for their Sitecore using the Docker files and configuration available simply by a method of pick and choose.

We have made a concious effort to make the life easy and we have also got this checked from some developers who also faced the challenges during their journey and they have felt that their effort is substancially reduced using this kit. This also tells us, that our effort is going in the right direction. But, we are also looking for inputs as well as contributions and the more inputs and contributions we get the better this kit will be at the end of the day.

Some inspiration also comes from a starter kit which was available during the Sitecore Hackathon 2021 and we are very thankful - because we took some ideas from it and it made our initial part easy. 

## Current Modules included as a part of the Starterkit

1. Sitecore Powershell Extensions (This gets added by default. There is no option of disabling this. Again, the reason this is by default, is because as a developer we always use PowerShell Extensions in our project and have to add it manually. So we have reduced that effort of installation.)
2. Sitecore Horizon (Option to Select if we want it)
3. Sitecore SXA (Option to Select if we want it)
4. Sitecore Publishing Service (Option to Select if we want it)
5. Sitecore Management Services (Option to Select if we want it)
6. Option for CD Role - even as a part of XP0 (In case we want to troubleshoot something, specific to CD, then that is what we can select and move ahead with. Again, with an option to Select if we want it)

## Initialize Script

*As the name suggests, this script helps a Sitecore Developer to initialize/begin with creating a Visual Studio Solution for Sitecore with Docker and all required configurations that might be useful to the developer who is working on a given project.*
*Also, in case there is a Docker folder or a Solution already configured, then it gets removed from the physical directory. Hence, please note that this script should only be executed ONCE -- which is during the very initial configuration of your project. In case there are any updates which are required, then Upgrade Script should be executed.*

1. 

## Start Script

*This Script is used to start the Docker Containers from the Images which got built as a part of the Initialize Script*
*It has two switches, Build and StopBeforeStarting*

**Build**: We can use this switch when we want to rebuild the images after making changes to the Docker file associated with any of the Sitecore roles.
**StopBeforeStarting**: We can use this switch when we have already running containers and for some reason we want to restart the entire set of containers. In that case, we first need to stop the ones which are running.


## Stop Script

*This Script is used to stop the running Docker Containers.*
*It is a must to execute this script, before Hibernating or turning your computer off - to avoid any kind of corruption.* 
*Please note, Windows takes good care of stopping the containers, and generally, we dont face any issue. But why take the risk?*
*Its like, before removing the USB Drive, we right click on the taskbar option, and click on **Safely Remove Hardware and Eject Media***


## Upgrade Script

*Now, after we setup the solution once, there is going to be a situation in the future, that we need to configure an additional module into the solution. That is the time when this Script is used*
*And hence, the name says, Upgrade - as in upgrading your solution and adding new modules to it.*
***Remember, do not execute Intialize Script again, otherwise, your Docker Folder as well as your Solution will be removed altogether.***

## Remove Script

*This is mainly for going back to Step 0 - where it deletes the solution and removes the Docker folder which got added to the solution as a part of running the Initialize Script.*
*Please note - this is a NON-REVERSIBLE Action - and is only added for Community members, who want to contribute to the Starterkit - to avoid them to waste anytime, deleting all the unnecessary files from the folder - before committing the changes to Git.*

## Contributors:

1. [Jatin Prajapati](https://twitter.com/jatin_praj)
2. [Varun Shringarpure](https://twitter.com/varunvns)
