ref [what-is-a-promptgram](./what-is-a-promptgram.md)

begin

defer [cleanup](../dev/cleanup.md)

CRITICAL RULE: Ralph works on EXACTLY ONE ticket per run. Once that ticket is complete, ralph MUST STOP. Do not work on another ticket. Do not create PRDs or ERDs. Ralph is DONE.

check git diff staged

if clean

    git fetch

    pull master

    find the next ticket to work on in the git project assoc with .

    if there is another ticket

    	work on the ticket ref [implement-ticket](../dev/implement-ticket.md)

    	CRITICAL: After completing this ONE ticket, STOP. Do not work on another ticket. Do not continue. Ralph is DONE.

    if there are no tickets in the backlog
        read the roadmap ref [roadmap](../roadmap/roadmap.md)
        identify the current phase and which features need PRDs
        create the next PRD for a feature from the current roadmap phase ref [prd](../product/prd.md)
        create the ERD to go with it ref [erd](../dev/erd.md)
        create the tickets and add them to the project ref [create-tickets-from-erd](../dev/create-tickets-from-erd.md)
        update the roadmap to link the new PRD
        commit and push ref [conventional-commits](../dev/conventional-commits.md)

        CRITICAL: After creating tickets, STOP. Do not work on any tickets. Ralph is DONE.

if not clean
use gh, check the tickets in the project, you're probably working on the current ticket, use whats already staged to figure it out, keep working on the ticket ref [implement-ticket](../dev/implement-ticket.md)

CRITICAL: After completing the current ticket, STOP. Do not work on another ticket. Ralph is DONE.

at end ALWAYS [cleanup](../dev/cleanup.md)
