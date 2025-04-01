import pyperclip

from datetime import datetime

PAYER = "Marcos"

def main():
    print("Insert CSV formatted expense lines:")
    lines = []
    while (line := input()) != "":
        lines.append(line)

    formatted_lines = []
    for line in lines:
        if line.count(",") == 2:
            date, description, value = line.split(",")
        elif line.count(",") == 4:
            date, value, _, _, description = line.split(",")
        formated_line = format_line(date, value, description)
        if formated_line:
            formatted_lines.append(formated_line)

    response = "\n".join(formatted_lines)
    print(response)
    pyperclip.copy(response)
    print("Final value copied to clipboard!")


def format_line(date, value, description) -> str:
    if float(value) >= 0:
        return None
    date = datetime.strptime(date, '%m/%d/%Y').strftime("%d/%m/%Y")
    description = description[1:description.rfind(" ")].strip().lower()
    value = str(abs(float(value))).replace(".", ",")
    return f"{date}\t \t{value}\t{PAYER}\t{description}"


if __name__ == "__main__":
    main()
