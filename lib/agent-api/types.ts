import { TopLevelSpec } from 'vega-lite';

export enum AgentMessageRole {
    SYSTEM = 'system',
    USER = 'user',
    ASSISTANT = 'assistant',
    DATA = 'data',
}

export interface AgentMessageTextContent {
    type: string,
    text: string,
}

export interface AgentMessageToolUseContent {
    type: string,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    tool_use: any;
}

export interface AgentMessageToolResultsContent {
    type: string,
    tool_results: {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        content: any[],
        name?: string;
    }
}

export interface AgentMessage {
    id: string;
    role: AgentMessageRole;
    content: (AgentMessageTextContent | AgentMessageToolUseContent | AgentMessageToolResultsContent)[];
}

export interface CortexAnalystTool {
    "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "analyst1"
    }
}

export interface CortexSearchTool {
    "tool_spec": {
        "type": "cortex_search",
        "name": "search1"
    }
}

export interface SqlExecTool {
    "tool_spec": {
        "type": "sql_exec",
        "name": "sql_exec"
    }
}

export interface DataToChartTool {
    "tool_spec": {
        "type": "data_to_chart",
        "name": "data_to_chart"
    }
}

export interface CortexAnalystToolResource {
    "analyst1": {
        "semantic_model_file": string;
    }
}

export interface CortexSearchToolResource {
    "search1": {
        "name": string;
        "max_results": number;
    }
}

export interface AgentRequestParams {
    model: string,
    experimental: {
        snowflakeIntelligence?: boolean;
        EnableRelatedQueries?: boolean;
    },
    messages: AgentMessage[],
    tools: (CortexAnalystTool | CortexSearchTool | SqlExecTool | DataToChartTool)[],
    tool_resources: (CortexAnalystToolResource | CortexSearchToolResource)[],
}

export interface Data2AnalyticsObject {
    explanation: string | null;
    chartSpec: TopLevelSpec | null;
}

export interface Citation {
    text: string;
    number: number;
}

export interface CortexSearchCitationSource {
    source_id: string | number;
    text: string;
    doc_id: string;
    doc_type: string;
}

export interface RelatedQuery {
    relatedQuery: string;
    answer: string;
}