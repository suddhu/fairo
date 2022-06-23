import argparse
from random import choice
# from datetime import datetime
# from copy import deepcopy
# import os
import random
# import json

SEED = 123

#  Read in the current annotated data
#  Generate conversational turns, paying attention to when there's an agent response
#  Make sure to add User: and Agent: tokens
#  Modify the NSP'' training gen script to prepend conv history from this file

AGENT_REPLIES = {
    "DROP": ["I don't understand what you want me to drop.", "I can't find it in my inventory!"],
    "DANCE": ["I don't know how to do that movement yet."],
    "DESTROY": ["I don't understand what you want me to destroy.", "I finished destroying this"],
    "DIG": ["Ok. I'll fill that hole up.", "I finished digging this."],
    "BUILD": ["I don't understand what you want me to build", "I finished building this"],
    "GET_MEMORY": ["I don't know what you're referring to."],
    "GET_CAPABILITIES": [
        'Try looking somewhere and tell me "build a wall there"',
        'Try looking at a structure and tell me "destroy that"',
        "Try building something and giving it a name",
        "Try naming something and telling me to build it"
        ],
    "GET": ["I don't understand what you want me to get.", "Got Item!", "I can't get this item. Giving up now"],
    "FILL": ["I finished filling this"],
    "UNDO": ["ok I will build it back.", "ok I will remove it."]
}

def main(opts):

    with open(opts.anno_data, "r") as f:
        anno_data = [l.strip() for l in f.readlines()]

    # Generate a map of commands to LFs
    command_map = {}
    for cmd in anno_data:
        cmd = cmd.split("|")
        command_map[cmd[1]] = cmd[2]

    # Store a list of commands and agent responses, if applicable, with the tokens prepended
    turn_list = []
    for k, v in command_map.items():
        turn = "User: " + k
        for reply_key in AGENT_REPLIES.keys():
            if reply_key in v:
                turn += " Agent: " + choice(AGENT_REPLIES[reply_key])
                break
        turn_list.append(turn)

    # Each command should be annotated once, with a variable amount of conversational history
    training_data = []
    for k,v in command_map.items():
        num_turns = random.randint(0, opts.max_turns)
        i = 0
        data_row = ""
        while i < num_turns:
            data_row += choice(turn_list) + " "
            i += 1

        data_row += "User: " + k + "|" + v + "\n"
        training_data.append(data_row)

    with open(opts.save_path, "w") as f:
        f.writelines(training_data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--max_turns",
        type=int,
        default=10,
        help="The maximum number of total chats to make up the conversational history",
    )
    parser.add_argument(
        "--anno_data",
        type=str,
        default="/private/home/ethancarlson/fairo/droidlet/artifacts/datasets/full_data/annotated.txt",
        help="Location of annotated.txt",
    )
    parser.add_argument(
        "--save_path",
        type=str,
        default="/private/home/ethancarlson/fairo/droidlet/artifacts/datasets/full_data/annotated_conversations.txt",
        help="Path and name of new training data file",
    )
    opts = parser.parse_args()

    main(opts)
