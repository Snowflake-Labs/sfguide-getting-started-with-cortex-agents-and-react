'use client';

import { AnimatePresence, motion } from 'framer-motion';
import { memo } from 'react';
import { AgentApiState, AgentMessage, AgentMessageRole, AgentMessageTextContent, AgentMessageToolResultsContent, AgentMessageToolUseContent, Citation, CortexSearchCitationSource, RELATED_QUERIES_REGEX, RelatedQuery } from '@/lib/agent-api';
import equal from 'fast-deep-equal';
import { prettifyChartSpec } from '@/lib/agent-api/functions/chat/prettifyChartSpec';
import { ChatTextComponent } from './chat-text-component';
import { ChatChartComponent } from './chat-chart-component';
import { ChatSQLComponent } from './chat-sql-component';
import { ChatTableComponent } from './chat-table-component';
import { ChatRelatedQueriesComponent } from './chat-related-queries-component';
import { ChatCitationsComponent } from './chat-citations-component';
import { Data2AnalyticsMessage } from './chat-data2-message';
import { postProcessAgentText } from '../functions/postProcessAgentText';

const PurePreviewMessage = ({
    message,
    agentState,
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    isLatestMessage,
}: {
    message: AgentMessage;
    agentState: AgentApiState,
    isLatestMessage: boolean,
}) => {
    // if only the search citations are available without text
    if (
        message.content.length === 2 &&
        message.content[0]?.type === "tool_use" &&
        (message?.content[0] as AgentMessageToolUseContent)?.tool_use?.name === "search1"
    ) {
        return null;
    }

    let agentApiText = "";
    const role = message.role;
    const citations: Citation[] = [];
    const relatedQueries: RelatedQuery[] = [];
    const agentResponses: React.ReactElement[] = [];

    // iterate over the message content and populate the agentResponses array
    // this logic is useful until we get names / keys associated with each text / tool_results responses to differentiate
    message.content.forEach((content) => {
        // if plain text
        if (content.type === "text") {
            const { text } = (content as AgentMessageTextContent);
            agentApiText = text;

            if (citations.length > 0) {
                relatedQueries.push(...text.matchAll(RELATED_QUERIES_REGEX).map(match => ({
                    relatedQuery: match[1].trim(),
                    answer: match[2].trim()
                })));
            }

            const postProcessedText = postProcessAgentText(text, relatedQueries, citations);

            agentResponses.push(<ChatTextComponent key={text} text={postProcessedText} role={role} />);
            // if analyst / search / data2analytics response
        } else if (content.type === "tool_results") {
            const toolResultsContent = (content as AgentMessageToolResultsContent).tool_results.content[0].json;

            // if search response
            if ("searchResults" in toolResultsContent) {
                citations.push(...toolResultsContent.searchResults.map((result: CortexSearchCitationSource) => ({
                    text: result.text,
                    number: parseInt(String(result.source_id), 10),
                })))
            }

            // if chart response
            if ("$schema" in toolResultsContent) {
                const chartSpec = prettifyChartSpec(toolResultsContent);
                agentResponses.push(<ChatChartComponent key={JSON.stringify(chartSpec)} chartSpec={chartSpec} />);
            }

            // if analyst text response
            if ("text" in toolResultsContent) {
                const { text } = toolResultsContent;
                agentResponses.push(<ChatTextComponent key={text} role={role} text={text} />);
            }

            // if analyst sql response
            if ("sql" in toolResultsContent) {
                const { sql } = toolResultsContent;
                agentResponses.push(<ChatSQLComponent key={sql} sql={sql} />);
            }

            // if execute sql response
        } else if (content.type === "sql_table") {
            const { text: tableMarkdown } = (content as AgentMessageTextContent);
            agentResponses.push(<ChatTableComponent key={tableMarkdown} tableMarkdown={tableMarkdown} open={false} />);
        }
    })

    return (
        <AnimatePresence>
            <motion.div
                className="w-full mx-auto max-w-3xl px-4 group/message"
                initial={{ y: 5, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                data-role={message.role}
            >
                <div
                    className='flex gap-4 w-full group-data-[role=user]/message:ml-auto group-data-[role=user]/message:max-w-lg group-data-[role=user]/message:w-fit'
                >

                    <div className="flex flex-col gap-4 w-full">
                        {agentResponses}

                        {role === AgentMessageRole.ASSISTANT && agentState === AgentApiState.EXECUTING_SQL && (
                            <Data2AnalyticsMessage message="Executing SQL..." />
                        )}

                        {role === AgentMessageRole.ASSISTANT && agentState === AgentApiState.RUNNING_ANALYTICS && (
                            <Data2AnalyticsMessage message="Analyzing data..." />
                        )}

                        {role === AgentMessageRole.ASSISTANT && relatedQueries.length > 0 && (
                            <ChatRelatedQueriesComponent relatedQueries={relatedQueries} />
                        )}

                        {role === AgentMessageRole.ASSISTANT && citations.length > 0 && agentState === AgentApiState.IDLE && agentApiText && (
                            <ChatCitationsComponent agentApiText={agentApiText} citations={citations} />
                        )}
                    </div>
                </div>
            </motion.div>
        </AnimatePresence>
    );
};

export const PreviewMessage = memo(
    PurePreviewMessage,
    (prevProps, nextProps) => {
        if (nextProps.isLatestMessage && !equal(prevProps.agentState, nextProps.agentState)) return false;
        if (!equal(prevProps.message.content, nextProps.message.content)) return false;
        return true;
    },
);